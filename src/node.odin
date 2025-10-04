package ygg;

import "core:fmt";
import "core:strings";

import types "types";
import utils "utils";

////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////// HIGH LEVEL API /////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////

begin_node :: proc (
    ctx:        ^types.Context,
    tag:        string,
    is_inline:  bool = false,
    style:      map[string]types.Option(string) = {},
    properties: map[string]types.Option(string) = {}) -> types.Result(types.Node) {
    using types;

    assert(ctx != nil, "[ERR]:\t| Error creating node: Context is nil!");

    result: Result(Node) = { error = NodeError.None, opt = utils.none(Node) };
    switch tag {
        case "html", "root", "main":    result.opt = utils.some(_create_node(ctx, tag = tag, id = 0));
        case "a":                       result = a(ctx, is_inline, style, properties);
        case "head":                    result = head(ctx, is_inline, style, properties);
        case "img", "Image":            result = img(ctx, is_inline, style, properties);
        case "input":                   result = input(ctx, is_inline, style, properties);
        case "li":                      result = li(ctx, is_inline, style, properties);
        case "link":                    result = link(ctx, is_inline, style, properties);
        case "meta":                    result = meta(ctx, is_inline, style, properties);
        case "nav":                     result = nav(ctx, is_inline, style, properties);
        case "ol":                      result = ol(ctx, is_inline, style, properties);
        case "p":                       result = p(ctx, is_inline, style, properties);
        case "script":                  result = script(ctx, is_inline, style, properties);
        case "span":                    result = span(ctx, is_inline, style, properties);
        case "table":                   result = table(ctx, is_inline, style, properties);
        case "td":                      result = td(ctx, is_inline, style, properties);
        case "tr":                      result = tr(ctx, is_inline, style, properties);
        case "th":                      result = th(ctx, is_inline, style, properties);
        case "title":                   result = title(ctx, is_inline, style, properties);
        case "ul":                      result = ul(ctx, is_inline, style, properties);
        case "video":                   result = video(ctx, is_inline, style, properties);
        case:                           result.opt = utils.some(_create_node(ctx, tag = tag));
    }

    if result.error == NodeError.None && is_inline {
        error := end_node(ctx, utils.unwrap(result.opt));
        if error != NodeError.None {
            return { error, utils.none(Node) };
        }
    }

    return result;
}

end_node :: proc (ctx: ^types.Context, node: types.Node, indent: string = "  ") -> types.NodeError {
    using types;

    error := _attach_node(ctx, node, indent = indent);
    if error != NodeError.None {
        fmt.printfln("[ERR]:{}|--- Error attaching node to tree: {}", indent, error);
        return error;
    }
    // TODO: Add to rendering pipeline
    // if node.is_renderable {
    //   error := renderer._enqueue_node(ctx, node);
    // }
    return NodeError.None;
}

a :: proc (
    ctx:        ^types.Context,
    is_inline:  bool = false,
    style:      map[string]types.Option(string) = {},
    properties: map[string]types.Option(string) = {}) -> types.Result(types.Node) {
    panic("Unimplemented");
}

head :: proc (
    ctx:        ^types.Context,
    is_inline:  bool = false,
    style:      map[string]types.Option(string) = {},
    properties: map[string]types.Option(string) = {}) -> types.Result(types.Node) {
    panic("Unimplemented");
}

img :: proc (
    ctx:        ^types.Context,
    is_inline:  bool = false,
    style:      map[string]types.Option(string) = {},
    properties: map[string]types.Option(string) = {}) -> types.Result(types.Node) {
    panic("Unimplemented");
}

input :: proc (
    ctx:        ^types.Context,
    is_inline:  bool = false,
    style:      map[string]types.Option(string) = {},
    properties: map[string]types.Option(string) = {}) -> types.Result(types.Node) {
    panic("Unimplemented");
}

li :: proc (
    ctx:        ^types.Context,
    is_inline:  bool = false,
    style:      map[string]types.Option(string) = {},
    properties: map[string]types.Option(string) = {}) -> types.Result(types.Node) {
    panic("Unimplemented");
}

link :: proc (
    ctx:        ^types.Context,
    is_inline:  bool = false,
    style:      map[string]types.Option(string) = {},
    properties: map[string]types.Option(string) = {}) -> types.Result(types.Node) {
    panic("Unimplemented");
}

meta :: proc (
    ctx:        ^types.Context,
    is_inline:  bool = false,
    style:      map[string]types.Option(string) = {},
    properties: map[string]types.Option(string) = {}) -> types.Result(types.Node) {
    panic("Unimplemented");
}

nav :: proc (
    ctx:        ^types.Context,
    is_inline:  bool = false,
    style:      map[string]types.Option(string) = {},
    properties: map[string]types.Option(string) = {}) -> types.Result(types.Node) {
    panic("Unimplemented");
}

ol :: proc (
    ctx:        ^types.Context,
    is_inline:  bool = false,
    style:      map[string]types.Option(string) = {},
    properties: map[string]types.Option(string) = {}) -> types.Result(types.Node) {
    panic("Unimplemented");
}

p :: proc (
    ctx:        ^types.Context,
    is_inline:  bool = false,
    style:      map[string]types.Option(string) = {},
    properties: map[string]types.Option(string) = {}) -> types.Result(types.Node) {
    panic("Unimplemented");
}

// High Level API to create and link a JS script.
script :: proc (
    ctx:        ^types.Context,
    is_inline:  bool = false,
    style:      map[string]types.Option(string) = {},
    properties: map[string]types.Option(string) = {}) -> types.Result(types.Node) {
    panic("Unimplemented");
}

span :: proc (
    ctx:        ^types.Context,
    is_inline:  bool = false,
    style:      map[string]types.Option(string) = {},
    properties: map[string]types.Option(string) = {}) -> types.Result(types.Node) {
    panic("Unimplemented");
}

table :: proc (
    ctx:        ^types.Context,
    is_inline:  bool = false,
    style:      map[string]types.Option(string) = {},
    properties: map[string]types.Option(string) = {}) -> types.Result(types.Node) {
    panic("Unimplemented");
}

td ::proc (
    ctx:        ^types.Context,
    is_inline:  bool = false,
    style:      map[string]types.Option(string) = {},
    properties: map[string]types.Option(string) = {}) -> types.Result(types.Node) {
    panic("Unimplemented");

}

th ::proc (
    ctx:        ^types.Context,
    is_inline:  bool = false,
    style:      map[string]types.Option(string) = {},
    properties: map[string]types.Option(string) = {}) -> types.Result(types.Node) {
    panic("Unimplemented");
}

tr :: proc (
    ctx:        ^types.Context,
    is_inline:  bool = false,
    style:      map[string]types.Option(string) = {},
    properties: map[string]types.Option(string) = {}) -> types.Result(types.Node) {
    panic("Unimplemented");

}

// High level API to create a h1-h9 node.
title :: proc (
    ctx:        ^types.Context,
    is_inline:  bool = false,
    style:      map[string]types.Option(string) = {},
    properties: map[string]types.Option(string) = {}) -> types.Result(types.Node) {
    panic("Unimplemented");
}

ul :: proc (
    ctx:        ^types.Context,
    is_inline:  bool = false,
    style:      map[string]types.Option(string) = {},
    properties: map[string]types.Option(string) = {}) -> types.Result(types.Node) {
    panic("Unimplemented");
}

video :: proc (
    ctx:        ^types.Context,
    is_inline:  bool = false,
    style:      map[string]types.Option(string) = {},
    properties: map[string]types.Option(string) = {}) -> types.Result(types.Node) {
    panic("Unimplemented");
}

// High-level API to find a node within the context tree. Note, this function is O(n) and yggdrasil
// does not support caching yet. Therefore, it is recommended that you save or cache your common
// queries to avoid impacting performance for large-scale applications.
//
// @param   ctx:    The current context - cannot be nil.
// @param   id:     The node ID you are looking for.
// @param   indent: The level of indent for all logs inside this function, open for fine-tuning.
// @return  Nil if the node was not found, the pointer to the node within the tree otherwise.
find_node :: proc (ctx: ^types.Context, id: types.Id, indent: string = "  ") -> ^types.Node {
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

    node_ptr := _flatten_and_find_node(ctx.root, find = id);

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

////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////// LOW LEVEL API //////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////

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
_create_node :: proc (
    ctx:        ^types.Context,
    tag:        string,
    id:         types.Option(int)                   = nil,
    parent:     ^types.Node                         = nil,
    style:      map[string]types.Option(string)   = { },
    properties: map[string]types.Option(string)   = { },
    children:   map[types.Id]types.Node             = { },
    indent:     string                              = "  "
) -> types.Node {
    using types;
    using utils;

    assert(ctx != nil, "[ERR]:\t| Error creating node: Context is nil!");

    level : LogLevel = into_debug(ctx.config["log_level"]);
    if level >= LogLevel.Verbose {
        fmt.printf("[INFO]:{}| Creating node ({{ tag = '{}', id = {}, parent?: '{}' [{}] (%p)}}) ...", indent, tag, id,
        parent != nil ? parent.tag : "nil", parent != nil ? parent.id : 0, parent);
    }

    parent: ^Node = parent != nil ? parent : ctx.last_node;
    new_id: int     = unwrap_or(id, 0);
    will_overflow  := _check_id_overflow(new_id);

    if will_overflow && level >= LogLevel.Normal {
        fmt.printfln("[WARN]:{}| Node with ID [{}] will overflow if attached to tree! " +
        "Modify [Id]'s alias to be a bigger type if you need to attach more nodes.",
        indent, new_id);
    }

    if !is_some(id) {
        new_id = int(ctx.nodes_created);
        ctx.nodes_created += 1;
    }

    if level >= LogLevel.Verbose {
        fmt.println(" Done");
    }

    return Node {
        parent = parent,
        id = Id(new_id),
        tag = tag,
        children = children,
        style = style,
        properties = properties
    };
}

// Deallocate a leaf and all of its children
_destroy_node :: proc (ctx: ^types.Context, id: types.Id, indent: string = "  ") -> types.NodeError {
    using types;
    using utils;

    assert(ctx != nil, "[ERR]:\t| Error destroying node: Context is nil!");

    level : LogLevel = into_debug(ctx.config["log_level"]);

    if level >= LogLevel.Verbose {
        fmt.printfln("[INFO]:{}| Destroying node [{}] ...", indent, id);
    }

    new_indent, _ := strings.concatenate({ indent, "  " });
    node_ptr := find_node(ctx, id, new_indent);
    delete_string(new_indent);

    if node_ptr == nil {
        if level >= LogLevel.Normal {
            fmt.eprintfln("[ERR]:{}--- Error destroying node: Node [{}] not found", indent, id);
        }
        return NodeError.NodeNotFound;
    }

    if node_ptr.parent != nil {
        node_ptr.parent.children[node_ptr.id] = {};
    }
    nodes_to_delete_ordered := _flatten_node(node_ptr);
    defer delete(nodes_to_delete_ordered);

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
        delete_map(node_to_delete.children);
    }

    if level >= LogLevel.Verbose {
        fmt.printfln("[INFO]:{}--- Done", indent);
    }

    return NodeError.None;
}

// Low-level API to attach a node to the current ui tree. Benefit of this function over its high-level counterparts
// 'begin_node(...)' is the ability to explicitely have control over when this node gets queued in the rendering
// pipeline, in case you needed to delay rendering after pre-processing, since the former will queue the node
// immediately without any say in it. Once a node is attached this way, only 'detach_node(...)' can remove it from
// the pipeline and NOT its end_<...> counterpart like the high-level API.
//
// @param ctx:    The current tree where we want to attach this node to. 
// @param node:   Which node is to be added to the tree
_attach_node :: proc (ctx: ^types.Context, node: types.Node, indent: string = "  ") -> types.NodeError {
    using types;
    using utils;

    assert(ctx != nil, "[ERR]:\t| Error attaching node: Context is nil!");

    level : LogLevel = into_debug(ctx.config["log_level"]);

    parent_ptr : ^Node = node.parent != nil ? node.parent : ctx.last_node;
    new_node   : Node  = node;

    if level >= LogLevel.Verbose {
        fmt.printfln("[INFO]:{}| Attaching node [tag = '{}', id = {} under '{}'] ...", indent, node.tag, node.id,
        parent_ptr != nil ? parent_ptr.tag : "nil");
    }

    if parent_ptr == nil {
        fmt.printfln("[WARN]:{}| No root found, setting '{}' as new root ...", indent, node.tag);
        ctx.root = new_clone(node);
        new_node   = ctx.root^;
        ctx.last_node = ctx.root;

    } else if ctx.last_node != parent_ptr {
        new_indent, _ := strings.concatenate({ indent, "  " });
        parent_ptr = find_node(ctx, parent_ptr.id, new_indent);
        delete_string(new_indent);

        if parent_ptr == nil {
            if level >= LogLevel.Normal {
                fmt.eprintfln("[WARN]:{}--- Node parent is nil, attaching to root instead ...", indent);
            }

            parent_ptr = ctx.root;
        }
    }

    if parent_ptr != nil && new_node.id == parent_ptr.id {
        fmt.printfln("[WARN]:{}| Overwriting root, setting '{}' as new root ...", indent, node.tag);
        free(ctx.root);
        ctx.root = new_clone(new_node);
        ctx.last_node = ctx.root;
    } else {
        new_node.parent = parent_ptr;
        if parent_ptr != nil {
            parent_ptr.children[node.id] = new_node;
            ctx.last_node = &parent_ptr.children[node.id];
        }
    }

    if level >= LogLevel.Verbose {
        if parent_ptr != nil {
            new_indent, _ := strings.concatenate({ indent, "  " });
            print_nodes(parent_ptr, new_indent);
            delete_string(new_indent);
        }

        fmt.printfln("[INFO]:{}--- Done (%p)", indent, ctx.last_node);
    }

    return NodeError.None
}

// Low-level API to detach a node in the current ui tree. Benefit of this function over its high-level counterparts
// 'end_node(...)' is the ability to explicitely have control over when this node gets dequeued from the rendering
// pipeline, in case you needed to delay rendering after pre-processing, since the former will dequeue the node
// immediately without any say in it. This will also detach children within the leaf, meaning it will remove all of
// the leaf's children as well from the context tree if it contains children.
//
// @param   *ctx*:    The current tree where we want to attach this node to.
// @param   *node*:   Which node is to be added to the tree
_detach_node :: proc (ctx: ^types.Context, id: types.Id, indent: string = "  ") -> types.Option(^types.Node) {
    using types;
    using utils;

    assert(ctx != nil, "[ERR]:\t| Error detaching node: Context is nil!");

    level : LogLevel = into_debug(ctx.config["log_level"]);
    if level >= LogLevel.Verbose {
        fmt.printfln("[INFO]:{}| Detaching [{}] from context tree ...", indent, id);
    }

    new_indent, _ := strings.concatenate({ indent, "  " });
    defer delete_string(new_indent);

    node_ptr := find_node(ctx, id, new_indent);

    if node_ptr == nil {
        if level >= LogLevel.Verbose {
            fmt.printfln("[WARN]:{}--- Cannot detach nil node, skipping ...", indent);
        }

        return none(^Node);
    }

    _destroy_node(ctx, id, new_indent);

    if level >= LogLevel.Verbose {
        fmt.printfln("[INFO]:{}--- Done", indent);
    }

    return node_ptr;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////// HELPERS /////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Helper to query the size of the entire node tree starting from the root provided from root to last inner leaf.
//
// @param   *root*:        A pointer that defines the start of the tree depth will be calculated from.
// @return  The total depth of the root specified, said differently, how many nodes to go into before
//          reaching the last inner leaf.
_get_node_depth :: proc (root: ^types.Node) -> types.Id {
    using types;

    if root == nil {
        return 0;
    }

    flat_nodes := _flatten_node(root);
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

// Helper to flatten all map nodes into a single dynamic sorted array, useful when you need to apply some
// uniform logic or transformation onto each node and their inner nodes.
//
// @param   *node_ptr*:     Which node to flatten with its children.
// @param   *stop_at*:      An ID that will stop the flattening process to act as an end bound.
// @return  The flattened list containing the node provided and all of its children.
_flatten_node :: proc (start_ptr: ^types.Node, stop_at: types.Option(types.Id) = nil) -> [dynamic]^types.Node {
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

// Helper to flatten all map nodes into a single dynamic sorted array, and use that to find the node id provided.
//
// @param   *start_ptr*:    Which node to flatten.
// @param   *find*:         ID to find when flattening nodes and once found, stop the flattening process.
// @return  The node to find (nil if not found).
_flatten_and_find_node :: proc (start_ptr: ^types.Node, find: types.Id) -> ^types.Node {
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
        if find == node.id {
            return node;
        }

        for _, &child in node.children {
            append(&to_visit, &child);
        }
    }

    return nil;
}
