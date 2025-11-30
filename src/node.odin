package ygg;

import fmt "core:fmt";

import types "types";
import utils "utils";

find_node :: proc {
    find_node_with_id,
    find_node_with_tag
}

// Core helper to find a node within the context tree. Note, this function is O(n) and yggdrasil
// does not support caching yet. Therefore, it is recommended that you save or cache your common
// queries to avoid impacting performance for large-scale applications.
//
// @param   ctx:    The current context - cannot be nil.
// @param   id:     The node ID you are looking for.
// @param   indent: The level of indent for all logs inside this function, open for fine-tuning.
// @return  Nil if the node was not found, the pointer to the node within the tree otherwise.
find_node_with_id :: proc (ctx: ^types.Context, id: types.Id, indent: string = "  ") -> ^types.Node {
    assert(ctx != nil, "[ERR]:\t| Error finding node: Context is nil!");

    log_level := utils.into_debug(ctx.config["log_level"]);

    if log_level >= types.LogLevel.Verbose {
        fmt.printf("[INFO]:{}| Searching for node id [{}] in context tree ...", indent, id);
    }

    if ctx.root == nil {
        if log_level >= types.LogLevel.Verbose {
            fmt.println(" Done");
        }
        return ctx.root;
    }

    if id == ctx.root.id {
        if log_level >= types.LogLevel.Verbose {
            fmt.println(" Done");
        }

        return ctx.root;
    }

    node_ptr := flatten_and_find_node(ctx.root, id = id);

    if node_ptr != nil && node_ptr.id == id {
        if log_level >= types.LogLevel.Verbose {
            fmt.println(" Done");
        }
        return node_ptr;
    }

    if log_level >= types.LogLevel.Verbose {
        fmt.printfln("\n[WARN]:{}--- Node not found", indent);
    }

    return nil;
}

find_node_with_tag :: proc (ctx: ^types.Context, tag: string, indent: string = "  ") -> ^types.Node {
    assert(ctx != nil, "[ERR]:\t| Error finding node: Context is nil!");

    log_level := utils.into_debug(ctx.config["log_level"]);

    if log_level >= types.LogLevel.Verbose {
        fmt.printf("[INFO]:{}| Searching for node id '{}' in context tree ...", indent, tag);
    }

    if ctx.root == nil {
        if log_level >= types.LogLevel.Verbose {
            fmt.println(" Done");
        }
        return ctx.root;
    }

    if tag == ctx.root.tag {
        if log_level >= types.LogLevel.Verbose {
            fmt.println(" Done");
        }

        return ctx.root;
    }

    node_ptr := flatten_and_find_node(ctx.root, tag = tag);

    if node_ptr != nil && node_ptr.tag == tag {
        if log_level >= types.LogLevel.Verbose {
            fmt.println(" Done");
        }
        return node_ptr;
    }

    if log_level >= types.LogLevel.Verbose {
        fmt.printfln("\n[WARN]:{}--- Node not found", indent);
    }

    return nil;
}

// Core API to query the size of the entire node tree starting from the root provided from root to last inner leaf.
//
// @param   *root*:        A pointer that defines the start of the tree depth will be calculated from.
// @return  The total depth of the root specified, said differently, how many nodes to go into before
//          reaching the last inner leaf.
get_node_depth :: proc (root: ^types.Node) -> types.Id {
    using types;

    if root == nil {
        return 0;
    }

    flat_nodes := flatten_node(root);
    defer delete_dynamic_array(flat_nodes);

    different_ids := make(map[^Node]bool);
    defer delete_map(different_ids);

    for node in flat_nodes {
        if node != nil && node != root {
            if _, ok := different_ids[node.parent]; !ok {
                different_ids[node.parent] = true;
            }
        }
    }

    return Id(len(different_ids));
}

// Core API to flatten all map nodes into a single dynamic sorted array, useful when you need to apply some
// uniform logic or transformation onto each node and their inner nodes.
//
// @param   *node_ptr*:     Which node to flatten with its children.
// @param   *stop_at*:      An ID that will stop the flattening process to act as an end bound.
// @return  The flattened list containing the node provided and all of its children.
flatten_node :: proc (start_ptr: ^types.Node, stop_at: types.Option(types.Id) = nil) -> [dynamic]^types.Node {
    using types;
    using utils;

    end_bound: Id = unwrap_or(stop_at, Id(_get_max_number(Id)))
    // Stack for DFS traversal, implemented with a dynamic array.
    to_visit := make([dynamic]^Node);
    defer delete(to_visit);

    // Flatten map to store the nodes in post-order (children first).
    flat_nodes := make([dynamic]^Node);

    append(&to_visit, start_ptr);

    // Dynamically grow the flat list of nodes, and only stop when all inner nodes have been explored.
    for len(to_visit) > 0 && len(to_visit) < int(end_bound) {
        node := pop(&to_visit);
        append(&flat_nodes, node);

        for _, &child in node.children {
            append(&to_visit, &child);
        }
    }

    return flat_nodes;
}

flatten_and_find_node :: proc {
    flatten_and_find_node_with_id,
    flatten_and_find_node_with_tag
}

// Core API to flatten all map nodes into a single dynamic sorted array, and use that to find the node id provided.
//
// @param   *start_ptr*:    Which node to flatten.
// @param   *find*:         ID to find when flattening nodes and once found, stop the flattening process.
// @return  The node to find (nil if not found).
flatten_and_find_node_with_id :: proc (start_ptr: ^types.Node, id: types.Id) -> ^types.Node {
    using types;

    // Stack for DFS traversal, implemented with a dynamic array.
    to_visit := make([dynamic]^Node);
    defer delete(to_visit);

    // Flatten map to store the nodes in post-order (children first).
    flat_nodes := make([dynamic]^Node);
    defer delete_dynamic_array(flat_nodes);

    append(&to_visit, start_ptr);

    // Dynamically grow the flat list of nodes, and only stop when all inner nodes have been explored.
    for len(to_visit) > 0 {
        node := pop(&to_visit);
        append(&flat_nodes, node);
        if id == node.id {
            return node;
        }

        for _, &child in node.children {
            append(&to_visit, &child);
        }
    }

    return nil;
}

// Core API to flatten all map nodes into a single dynamic sorted array, and use that to find the first node tag provided.
//
// @param   *start_ptr*:    Which node to flatten.
// @param   *find*:         Tag to find when flattening nodes and once found, stop the flattening process.
// @return  The node to find (nil if not found).
flatten_and_find_node_with_tag :: proc (start_ptr: ^types.Node, tag: string) -> ^types.Node {
    using types;

    // Stack for DFS traversal, implemented with a dynamic array.
    to_visit := make([dynamic]^Node);
    defer delete(to_visit);

    // Flatten map to store the nodes in post-order (children first).
    flat_nodes := make([dynamic]^Node);
    defer delete_dynamic_array(flat_nodes);

    append(&to_visit, start_ptr);

    // Dynamically grow the flat list of nodes, and only stop when all inner nodes have been explored.
    for len(to_visit) > 0 {
        node := pop(&to_visit);
        append(&flat_nodes, node);
        if tag == node.tag {
            return node;
        }

        for _, &child in node.children {
            append(&to_visit, &child);
        }
    }

    return nil;
}
