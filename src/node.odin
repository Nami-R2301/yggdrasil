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
create_node :: proc "c" (
    ctx:        runtime.Context,
    tag:        string,
    id:         types.Option(int) = nil,
    parent:     ^types.Node = nil,
    style:      map[string]types.Option(string) = { },
    children:   map[types.Id]types.Node = { },
    user_data:  rawptr = nil,
    indent:     string = "  ") -> types.Node {
    using types;
    using utils;

    context = ctx;

    ygg_ctx := cast(^Context)ctx.user_ptr;
    assert_contextless(ygg_ctx != nil, "[ERR]:\tCannot create node: Context is nil. Did you forget to call 'create_context(...)' ?");

    level : LogLevel = into_debug(ygg_ctx.config["log_level"]);
    if level >= LogLevel.Verbose {
        fmt.printf("[INFO]:{}| Creating node ({{ tag = '{}', id = {}, parent?: '{}' [{}] (%p)}}) ...", indent, tag, id,
        parent != nil ? parent.tag : "nil", parent != nil ? parent.id : 0, parent);
    }

    parent_node     := parent != nil ? parent : ygg_ctx.last_node;
    new_id: int     = unwrap_or(id, 0);
    will_overflow   := check_id_overflow(new_id);

    if will_overflow {
        fmt.printfln("[WARN]:{}| Node with ID [{}] will overflow if attached to tree! " +
        "Modify [Id]'s alias to be a bigger type if you need to attach more nodes.",
        indent, new_id);
    }

    if !is_some(id) && parent_node != nil {
        new_id = int(parent_node.id + Id(len(parent_node.children) + 1));
    }

    return Node {
        parent = parent_node,
        id = Id(new_id),
        tag = tag,
        children = children,
        style = style,
        user_data = user_data,
    };
}

// Deallocate a leaf and all of its children
destroy_node :: proc "c" (
    ctx: runtime.Context,
    id: types.Id,
    indent: string = "  ") -> types.Option(^types.Node) {
    using types;
    using utils;


    context = ctx;
    ygg_ctx := cast(^types.Context)ctx.user_ptr;
    assert_contextless(ygg_ctx != nil, "[ERR]:\tCannot destroy node: Context is nil. Did you forget to call 'create_context(...)' ?");

    level : LogLevel = into_debug(ygg_ctx.config["log_level"]);
    if level >= LogLevel.Verbose {
        fmt.printfln("[INFO]:{}| Destroying node [{}] ...", indent, id);
    }

    new_indent, err := strings.concatenate({indent, "  "}, context.temp_allocator);
    if err != mem.Allocator_Error.None {
        fmt.eprintfln("[ERR]:{} --- Cannot destroy node: Alloc error: {}", indent, err);
        panic("Alloc error (Buy more ram)");
    }

    node_ptr := find_node(ctx, id, new_indent);

    if node_ptr == nil {
        if level >= LogLevel.Normal {
            fmt.eprintfln("[ERR]:{} --- Error destroying node: Node [{}] not found", indent, id);
        }
        return utils.none(^Node);
    }

    nodes_to_delete_ordered := flatten_node(node_ptr, allocator = context.temp_allocator);

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

    if level >= LogLevel.Verbose {
        fmt.printfln("[INFO]:{}--- Done", indent);
    }

    return utils.some(node_ptr);
}

// Low-level API to attach a node to the current ui tree. Benefit of this function over its high-level counterparts
// 'begin_node(...)' is the ability to explicitely have control over when this node gets queued in the rendering
// pipeline, in case you needed to delay rendering after pre-processing, since the former will queue the node
// immediately without any say in it. Once a node is attached this way, only 'detach_node(...)' can remove it from
// the pipeline and NOT its end_<...> counterpart like the high-level API.
//
// @param ctx:    The current tree where we want to attach this node to.
// @param node:   Which node is to be added to the tree
attach_node :: proc "c" (
    ctx:    runtime.Context,
    node:   types.Node,
    indent: string = "  ") {
    using types;
    using utils;


    context = ctx;
    ygg_ctx := cast(^types.Context)ctx.user_ptr;
    assert_contextless(ygg_ctx != nil, "[ERR]:\tCannot attach node: Context is nil. Did you forget to call 'create_context(...)' ?");

    level : LogLevel = into_debug(ygg_ctx.config["log_level"]);

    parent_ptr : ^Node = node.parent != nil ? node.parent : ygg_ctx.last_node;
    new_node   : Node  = node;
    mem_err: mem.Allocator_Error;

    if level >= LogLevel.Verbose {
        fmt.printfln("[INFO]:{}| Attaching node [tag = '{}', id = {} under '{}'] ...", indent, node.tag, node.id,
        parent_ptr != nil ? parent_ptr.tag : "nil");
    }

    if parent_ptr == nil {
        ygg_ctx.root, mem_err = new_clone(node, ctx.allocator);
        assert(mem_err == mem.Allocator_Error.None, "[ERR]:\tCannot attach node: Out of memory (buy more ram)");
        new_node   = ygg_ctx.root^;
        ygg_ctx.last_node = ygg_ctx.root;

    } else if ygg_ctx.last_node != parent_ptr {
        new_indent, mem_error := strings.concatenate({indent, "  "}, context.temp_allocator);
        assert(mem_error == mem.Allocator_Error.None, "[ERR]:\tCannot attach node: Out of memory (buy more ram)");

        parent_ptr = find_node(ctx, parent_ptr.id, new_indent);

        if parent_ptr == nil {
            if level >= LogLevel.Normal {
                fmt.eprintfln("[WARN]:{}--- Node parent is nil, attaching to root instead ...", indent);
            }

            parent_ptr = ygg_ctx.root;
        }
    }

    if parent_ptr != nil && new_node.id == parent_ptr.id {
        fmt.printfln("[WARN]:{}| Overwriting root, setting '{}' as new root ...", indent, node.tag);
        free(ygg_ctx.root, ctx.allocator);
        ygg_ctx.root, mem_err = new_clone(new_node, ctx.allocator);
        assert(mem_err == mem.Allocator_Error.None, "[ERR]:\tCannot attach node: Out of memory (buy more ram)");

        ygg_ctx.last_node = ygg_ctx.root;
    } else {
        new_node.parent = parent_ptr;
        if parent_ptr != nil {
            parent_ptr.children[node.id] = new_node;
            ygg_ctx.last_node = &parent_ptr.children[node.id];
        }
    }

    if level >= LogLevel.Verbose {
        new_indent, mem_error := strings.concatenate({indent, "  "}, context.temp_allocator);
        assert(mem_error == mem.Allocator_Error.None, "[ERR]:\tCannot attach node: Out of memory (buy more ram)");

        if parent_ptr != nil {
            print_nodes(parent_ptr, new_indent);
        }

        fmt.printfln("[INFO]:{}--- Done (%p)", indent, ygg_ctx.last_node);
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
detach_node :: proc "c" (
    ctx: runtime.Context,
    id: types.Id,
    indent: string = "  ") -> types.Option(^types.Node) {
    using types;
    using utils;

    context = ctx;
    ygg_ctx: ^Context = cast(^Context)ctx.user_ptr;
    assert_contextless(ygg_ctx != nil, "[ERR]:\tCannot detach node: Context is nil. Did you forget to call 'create_context(...)' ?");

    level : LogLevel = into_debug(ygg_ctx.config["log_level"]);
    if level >= LogLevel.Verbose {
        fmt.printfln("[INFO]:{}| Detaching [{}] from context tree ...", indent, id);
    }

    new_indent, err := strings.concatenate({ indent, "  " }, context.temp_allocator);
    if err != mem.Allocator_Error.None {
        fmt.eprintfln("[ERR]:{} --- Error detaching [{}] from context tree:", indent, id, err);
        return none(^Node);
    }

    node_ptr := destroy_node(ctx, id, indent = new_indent);

    if level >= LogLevel.Verbose {
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
find_node_with_id :: proc "c" (
    ctx:    runtime.Context,
    id:     types.Id,
    indent: string = "  ") -> ^types.Node {
    using types;


    context = ctx;
    ygg_ctx := cast(^Context)ctx.user_ptr;
    assert_contextless(ygg_ctx != nil, "[ERR]:\tCannot find node: Context is nil. Did you forget to call 'create_context(...)' ?");

    log_level := utils.into_debug(ygg_ctx.config["log_level"]);

    if log_level >= LogLevel.Verbose {
        fmt.printf("[INFO]:{}| Searching for node id [{}] in context tree ...", indent, id);
    }

    if ygg_ctx.root == nil {
        if log_level >= LogLevel.Verbose {
            fmt.println(" Done");
        }
        return ygg_ctx.root;
    }

    if id == ygg_ctx.root.id {
        if log_level >= LogLevel.Verbose {
            fmt.println(" Done");
        }

        return ygg_ctx.root;
    }

    node_ptr := flatten_and_find_node(ygg_ctx.root, id = id, allocator = context.temp_allocator);

    if node_ptr != nil && node_ptr.id == id {
        if log_level >= LogLevel.Verbose {
            fmt.println(" Done");
        }
        return node_ptr;
    }

    if log_level >= LogLevel.Verbose {
        fmt.printfln("\n[WARN]:{}--- Node not found", indent);
    }

    return nil;
}

find_node_with_tag :: proc "c" (
    ctx:    runtime.Context,
    tag:    string,
    indent: string = "  ") -> ^types.Node {
    using types;


    context = ctx;
    ygg_ctx := cast(^Context)ctx.user_ptr;
    assert_contextless(ygg_ctx != nil, "[ERR]:\tCannot create node: Context is nil. Did you forget to call 'create_context(...)' ?");

    log_level := utils.into_debug(ygg_ctx.config["log_level"]);

    if log_level >= LogLevel.Verbose {
        fmt.printf("[INFO]:{}| Searching for node id '{}' in context tree ...", indent, tag);
    }

    if ygg_ctx.root == nil {
        if log_level >= LogLevel.Verbose {
            fmt.println(" Done");
        }
        return ygg_ctx.root;
    }

    if tag == ygg_ctx.root.tag {
        if log_level >= LogLevel.Verbose {
            fmt.println(" Done");
        }

        return ygg_ctx.root;
    }

    node_ptr := flatten_and_find_node(ygg_ctx.root, tag = tag, allocator = context.temp_allocator);

    if node_ptr != nil && node_ptr.tag == tag {
        if log_level >= LogLevel.Verbose {
            fmt.println(" Done");
        }
        return node_ptr;
    }

    if log_level >= LogLevel.Verbose {
        fmt.printfln("\n[WARN]:{}--- Node not found", indent);
    }

    return nil;
}

// Core API to query the size of the entire node tree starting from the root provided from root to last inner leaf.
//
// @param   *root*:        A pointer that defines the start of the tree depth will be calculated from.
// @return  The total depth of the root specified, said differently, how many nodes to go into before
//          reaching the last inner leaf.
get_node_depth :: proc "c" (root: ^types.Node, allocator: mem.Allocator) -> types.Id {
    using types;

    if root == nil {
        return 0;
    }

    context = runtime.default_context();

    flat_nodes := flatten_node(root, allocator = allocator);
    different_ids := make(map[^Node]bool, allocator = allocator);

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
flatten_node :: proc "c" (
    start_ptr: ^types.Node,
    stop_at: types.Option(types.Id) = nil,
    allocator: mem.Allocator) -> [dynamic]^types.Node {
    using types;
    using utils;

    context = runtime.default_context();

    end_bound: Id = unwrap_or(stop_at, Id(get_max_number(Id)));

    // Stack for DFS traversal, implemented with a dynamic array.
    to_visit := make([dynamic]^Node, allocator = allocator);

    // Flatten map to store the nodes in post-order (children first).
    flat_nodes := make([dynamic]^Node, allocator = allocator);

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
flatten_and_find_node_with_id :: proc "c" (
    start_ptr: ^types.Node,
    id: types.Id,
    allocator: mem.Allocator) -> ^types.Node {
    using types;

    context = runtime.default_context();
    context.temp_allocator = allocator;

    // Stack for DFS traversal, implemented with a dynamic array.
    to_visit := make([dynamic]^Node, allocator);

    // Flatten map to store the nodes in post-order (children first).
    flat_nodes := make([dynamic]^Node, allocator);
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
flatten_and_find_node_with_tag :: proc "c" (
    start_ptr: ^types.Node,
    tag: string,
    allocator: mem.Allocator) -> ^types.Node {
    using types;

    context = runtime.default_context();
    context.temp_allocator = allocator;

    // Stack for DFS traversal, implemented with a dynamic array.
    to_visit := make([dynamic]^Node, allocator);

    // Flatten map to store the nodes in post-order (children first).
    flat_nodes := make([dynamic]^Node, allocator);
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
