package ygg;

import fmt      "core:fmt";
import mem      "core:mem";
import strings  "core:strings";
import runtime  "base:runtime";

import types "types";
import utils "utils";

// Low-level API to create a custom UI node, to be attached onto the tree later on. This is normally intended
// to be abstracted away from the programmer behind high-level API entrypoints like 'begin_node'. One might
// use this function to wait and prevent the automatic rendering mechanisms provided and performed by 'begin_node',
// i.e. for a temporary node that does not live long enough to reach end of frame (Cleaned up with '_destroy_node(...)').
//
// Another common use-case would be to use this newly-created node from this function to only store and hold information
// that might happen within a cycle, without expanding the tree unnecessarily (data-nodes).
//
// @lifetime:           This function does NOT cleanup after itself, hence 'destroy_node(..)'
//                      is needed for each corresponding 'create_node' in the frame's scope.
// @param ctx:          The tree containing all nodes to be processed.
// @param tag:          Which tag identifier will be used to lookup the node in the map. Tag needs to be unique, unless
//                      you are planning to override the existing node.
// @param id:           Unique identifier to lookup node when processing.
// @param style:        CSS-like style mapping to be applied upon rendering on each frame.
// @param properties:   Data map to store information related to the node as well as override default ones
//                      (alt, disabled, type, etc...), which will mutate the node's functionality.
// @param children:     The leaf nodes related under this one,
// @return              An error if one is encountered and the node created.
@(export, link_prefix="ygg_", require_results)
create_node :: proc "c" (
    ctx:        ^types.Context,
    tag:        string,
    id:         Maybe(int) = nil,
    parent:     ^types.Node = nil,
    style:      map[string]Maybe(string) = { },
    children:   map[types.Id]types.Node = { },
    user_data:  rawptr = nil,
    indent:     cstring = "  ") -> types.Node {
    assert_contextless(ctx != nil, "[ERR]:\tCannot create node: Context is nil. Did you forget to call 'create_context(...)' ?");
    context = ctx^._context;

    level: types.LogLevel = ctx.log_level;
    if level >= types.LogLevel.Verbose {
        fmt.printf("[INFO]:{}| Creating node ({{ tag = '{}', id = {}, parent?: '{}' [{}] (%p)}}) ...", indent, tag, id,
        parent != nil ? parent.tag : "nil", parent != nil ? parent.id : 0, parent);
    }

    parent_node     := parent != nil ? parent : ctx.last_node;
    new_id: int     = utils.unwrap_or(id, 0);
    will_overflow   := utils.check_id_overflow(new_id);

    if will_overflow {
        fmt.printfln("[WARN]:{}| Node with ID [{}] will overflow if attached to tree! " +
        "Modify [Id]'s alias to be a bigger type if you need to attach more nodes.",
        indent, new_id);
    }

    if utils.is_none(id) && parent_node != nil {
        new_id = int(parent_node.id + types.Id(len(parent_node.children) + 1));
    }

    return types.Node {
        parent = parent_node,
        id = types.Id(new_id),
        tag = tag,
        children = children,
        style = style,
        user_data = user_data,
    };
}

// Deallocate a leaf and all of its children
@(export, link_prefix="ygg_")
destroy_node :: proc "c" (
    ctx:    ^types.Context,
    id:     types.Id,
    indent: cstring = "  ") -> Maybe(types.Node) {
    assert_contextless(ctx != nil, "[ERR]:\tCannot destroy node: Context is nil. Did you forget to call 'create_context(...)' ?");
    context = ctx^._context;

    level: types.LogLevel = ctx.log_level;
    if level >= types.LogLevel.Verbose {
        fmt.printfln("[INFO]:{}| Destroying node [{}] ...", indent, id);
    }

    new_indent, err := strings.concatenate({string(indent), "  "}, context.temp_allocator);
    c_indent := cstring(raw_data(new_indent));
    if err != mem.Allocator_Error.None {
        fmt.eprintfln("[ERR]:{} --- Cannot destroy node: Alloc error: {}", indent, err);
        panic("Alloc error (Buy more ram)");
    }

    node_ptr := find_node(ctx, id, c_indent);

    if node_ptr == nil {
        if level >= types.LogLevel.Normal {
            fmt.eprintfln("[ERR]:{} --- Error destroying node: Node [{}] not found", indent, id);
        }
        return nil;
    }

    nodes_to_delete_ordered := flatten_nodes(node_ptr, allocator = context.temp_allocator);

    // Reverse the list to get the correct post-order traversal.
    // This ensures we process children before their parents.
    {
        low := 0;
        high := len(nodes_to_delete_ordered) - 1;
        for low < high {
        // Swap
            nodes_to_delete_ordered[low],  nodes_to_delete_ordered[high] =
            nodes_to_delete_ordered[high], nodes_to_delete_ordered[low];
            low += 1;
            high -= 1;
        }
    }

    for node_to_delete in nodes_to_delete_ordered {
        if len(node_to_delete.children) != 0 {
            delete_map(node_to_delete.children);
            if err != mem.Allocator_Error.None {
                fmt.eprintfln("[ERR]:{} --- Cannot destroy node: Memory error: {}", indent, err);
                panic("De-allocation error");
            }
        }

        if len(node_to_delete.style) != 0 {
            delete_map(node_to_delete.style);
            if err != mem.Allocator_Error.None {
                fmt.eprintfln("[ERR]:{} --- Cannot destroy node: Memory error: {}", indent, err);
                panic("De-allocation error");
            }
        }
    }

    if level >= types.LogLevel.Verbose {
        fmt.printfln("[INFO]:{}--- Done", indent);
    }

    return node_ptr^;
}

// Low-level API to attach a node to the current ui tree. Benefit of this function over its high-level counterparts
// 'begin_node(...)' is the ability to explicitely have control over when this node gets queued in the rendering
// pipeline, in case you needed to delay rendering after pre-processing, since the former will queue the node
// immediately without any say in it. Once a node is attached this way, only 'detach_node(...)' can remove it from
// the pipeline and NOT its end_<...> counterpart like the high-level API.
//
// @param ctx:    The current tree where we want to attach this node to.
// @param node:   Which node is to be added to the tree
@(export, link_prefix="ygg_")
attach_node :: proc "c" (
    ctx:    ^types.Context,
    node:   types.Node,
    indent: cstring = "  ") {
    assert_contextless(ctx != nil, "[ERR]:\tCannot attach node: Context is nil. Did you forget to call 'create_context(...)' ?");
    context = ctx._context;

    level: types.LogLevel = ctx.log_level;
    parent_ptr : ^types.Node = node.parent != nil ? node.parent : ctx.last_node;
    new_node   : types.Node  = node;
    mem_err: mem.Allocator_Error;

    if level >= types.LogLevel.Verbose {
        fmt.printfln("[INFO]:{}| Attaching node [tag = '{}', id = {} under '{}'] ...", indent, node.tag, node.id,
        parent_ptr != nil ? parent_ptr.tag : "nil");
    }

    if parent_ptr == nil {
        ctx.root, mem_err = new_clone(node);
        assert(mem_err == mem.Allocator_Error.None, "[ERR]:\tCannot attach node: Out of memory (buy more ram)");
        new_node   = ctx.root^;
        ctx.last_node = ctx.root;

    } else if ctx.last_node != parent_ptr {
        new_indent, mem_error := strings.concatenate({string(indent), "  "}, context.temp_allocator);
        c_indent := cstring(raw_data(new_indent));
        assert(mem_error == mem.Allocator_Error.None, "[ERR]:\tCannot attach node: Out of memory (buy more ram)");

        parent_ptr = find_node(ctx, parent_ptr.id, c_indent);

        if parent_ptr == nil {
            if level >= types.LogLevel.Normal {
                fmt.eprintfln("[WARN]:{}--- Node parent is nil, attaching to root instead ...", indent);
            }

            parent_ptr = ctx.root;
        }
    }

    if parent_ptr != nil && new_node.id == parent_ptr.id {
        fmt.printfln("[WARN]:{}| Overwriting root, setting '{}' as new root ...", indent, node.tag);
        free(ctx.root);
        ctx.root, mem_err = new_clone(new_node);
        assert(mem_err == mem.Allocator_Error.None, "[ERR]:\tCannot attach node: Out of memory (buy more ram)");

        ctx.last_node = ctx.root;
    } else {
        new_node.parent = parent_ptr;
        if parent_ptr != nil {
            parent_ptr.children[node.id] = new_node;
            ctx.last_node = &parent_ptr.children[node.id];
        }
    }

    if level >= types.LogLevel.Verbose {
        new_indent, mem_error := strings.concatenate({string(indent), "  "}, context.temp_allocator);
        c_indent := cstring(raw_data(new_indent));
        assert(mem_error == mem.Allocator_Error.None, "[ERR]:\tCannot attach node: Out of memory (buy more ram)");

        if parent_ptr != nil {
            print_nodes(parent_ptr, c_indent);
        }

        fmt.printfln("[INFO]:{}--- Done (%p)", indent, ctx.last_node);
    }
}

// Low-level API to detach a node in the current ui tree. Benefit of this function over its high-level counterparts
// 'end_node(...)' is the ability to explicitely have control over when this node gets dequeued from the rendering
// pipeline, in case you needed to delay rendering after pre-processing, since the former will dequeue the node
// immediately without any say in it. This will also detach children within the leaf, meaning it will remove all of
// the leaf's children as well from the context tree if it contains children.
//
// @param   *ctx*:    The current tree where we want to attach this node to.
// @param   *node*:   Which node is to be added to the tree
@(export, link_prefix="ygg_")
detach_node :: proc "c" (
    ctx:    ^types.Context,
    id:     types.Id,
    indent: cstring = "  ") -> Maybe(types.Node) {
    assert_contextless(ctx != nil, "[ERR]:\tCannot detach node: Context is nil. Did you forget to call 'create_context(...)' ?");
    context = ctx._context;

    level: types.LogLevel = ctx.log_level;
    if level >= types.LogLevel.Verbose {
        fmt.printfln("[INFO]:{}| Detaching [{}] from context tree ...", indent, id);
    }

    new_indent, err := strings.concatenate({ string(indent), "  " }, context.temp_allocator);
    if err != mem.Allocator_Error.None {
        fmt.eprintfln("[ERR]:{} --- Error detaching [{}] from context tree:", indent, id, err);
        return nil;
    }

    c_indent := cstring(raw_data(new_indent));
    node_ptr := destroy_node(ctx, id, indent = c_indent);

    if level >= types.LogLevel.Verbose {
        fmt.printfln("[INFO]:{}--- Done", indent);
    }

    return node_ptr;
}

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
@(export, link_prefix="ygg_")
find_node_with_id :: proc "c" (
    ctx:    ^types.Context,
    id:     types.Id,
    indent: cstring = "  ") -> ^types.Node {
    assert_contextless(ctx != nil, "[ERR]:\tCannot find node: Context is nil. Did you forget to call 'create_context(...)' ?");
    context = ctx._context;

    level: types.LogLevel = ctx.log_level;
    if level >= types.LogLevel.Verbose {
        fmt.printf("[INFO]:{}| Searching for node id [{}] in context tree ...", indent, id);
    }

    if ctx.root == nil {
        if level >= types.LogLevel.Verbose {
            fmt.println(" Done");
        }
        return ctx.root;
    }

    if id == ctx.root.id {
        if level >= types.LogLevel.Verbose {
            fmt.println(" Done");
        }

        return ctx.root;
    }

    node_ptr := flatten_and_find_node(ctx.root, id = id, allocator = context.temp_allocator);

    if node_ptr != nil && node_ptr.id == id {
        if level >= types.LogLevel.Verbose {
            fmt.println(" Done");
        }
        return node_ptr;
    }

    if level >= types.LogLevel.Verbose {
        fmt.printfln("\n[WARN]:{}--- Node not found", indent);
    }

    return nil;
}

@(export, link_prefix="ygg_")
find_node_with_tag :: proc "c" (
    ctx:    ^types.Context,
    tag:    string,
    indent: cstring = "  ") -> ^types.Node {
    assert_contextless(ctx != nil, "[ERR]:\tCannot create node: Context is nil. Did you forget to call 'create_context(...)' ?");
    context = ctx._context;

    level: types.LogLevel = ctx.log_level;
    if level >= types.LogLevel.Verbose {
        fmt.printf("[INFO]:{}| Searching for node id '{}' in context tree ...", indent, tag);
    }

    if ctx.root == nil {
        if level >= types.LogLevel.Verbose {
            fmt.println(" Done");
        }
        return ctx.root;
    }

    if tag == ctx.root.tag {
        if level >= types.LogLevel.Verbose {
            fmt.println(" Done");
        }

        return ctx.root;
    }

    node_ptr := flatten_and_find_node(ctx.root, tag = tag, allocator = context.temp_allocator);

    if node_ptr != nil && node_ptr.tag == tag {
        if level >= types.LogLevel.Verbose {
            fmt.println(" Done");
        }
        return node_ptr;
    }

    if level >= types.LogLevel.Verbose {
        fmt.printfln("\n[WARN]:{}--- Node not found", indent);
    }

    return nil;
}

// Core API to query the size of the entire node tree starting from the root provided from root to last inner leaf.
//
// @param   *root*:        A pointer that defines the start of the tree depth will be calculated from.
// @return  The total depth of the root specified, said differently, how many nodes to go into before
//          reaching the last inner leaf.
@(export, link_prefix="ygg_")
get_node_depth :: proc "c" (root: ^types.Node, allocator: mem.Allocator) -> types.Id {
    if root == nil {
        return 0;
    }

    context = runtime.default_context();

    flat_nodes := flatten_nodes(root, allocator = allocator);
    different_ids := make(map[^types.Node]bool, allocator = allocator);

    for node in flat_nodes {
        if node != nil && node != root {
            if _, ok := different_ids[node.parent]; !ok {
                different_ids[node.parent] = true;
            }
        }
    }

    return types.Id(len(different_ids));
}

// Core API to flatten all map nodes into a single dynamic sorted array, useful when you need to apply some
// uniform logic or transformation onto each node and their inner nodes.
//
// @param   *node_ptr*:     Which node to flatten with its children.
// @param   *stop_at*:      An ID that will stop the flattening process to act as an end bound.
// @return  The flattened list containing the node provided and all of its children.
@(export, link_prefix="ygg_")
flatten_nodes :: proc "c" (
    start_ptr:  ^types.Node,
    stop_at:    Maybe(types.Id) = {},
    allocator:  mem.Allocator) -> [dynamic]^types.Node {
    context = runtime.default_context();

    end_bound: types.Id = utils.unwrap_or(stop_at, types.Id(utils.get_max_number(types.Id)));

    // Stack for DFS traversal, implemented with a dynamic array.
    to_visit := make([dynamic]^types.Node, allocator = allocator);

    // Flatten map to store the nodes in post-order (children first).
    flat_nodes := make([dynamic]^types.Node, allocator = allocator);

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
@(export, link_prefix="ygg_")
flatten_and_find_node_with_id :: proc "c" (
    start_ptr: ^types.Node,
    id: types.Id,
    allocator: mem.Allocator) -> ^types.Node {
    context = runtime.default_context();
    context.temp_allocator = allocator;

    // Stack for DFS traversal, implemented with a dynamic array.
    to_visit := make([dynamic]^types.Node, allocator);
    // Flatten map to store the nodes in post-order (children first).
    flat_nodes := make([dynamic]^types.Node, allocator);
    append_elem(&to_visit, start_ptr);

    // Dynamically grow the flat list of nodes, and only stop when all inner nodes have been explored.
    for len(to_visit) > 0 {
        node := pop(&to_visit);
        append_elem(&flat_nodes, node);
        if id == node.id {
            return node;
        }

        for _, &child in node.children {
            append_elem(&to_visit, &child);
        }
    }

    return nil;
}

// Core API to flatten all map nodes into a single dynamic sorted array, and use that to find the first node tag provided.
//
// @param   *start_ptr*:    Which node to flatten.
// @param   *find*:         Tag to find when flattening nodes and once found, stop the flattening process.
// @return  The node to find (nil if not found).
@(export, link_prefix="ygg_")
flatten_and_find_node_with_tag :: proc "c" (
    start_ptr: ^types.Node,
    tag: string,
    allocator: mem.Allocator) -> ^types.Node {
    context = runtime.default_context();
    context.temp_allocator = allocator;

    // Stack for DFS traversal, implemented with a dynamic array.
    to_visit := make([dynamic]^types.Node, allocator);

    // Flatten map to store the nodes in post-order (children first).
    flat_nodes := make([dynamic]^types.Node, allocator);
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
