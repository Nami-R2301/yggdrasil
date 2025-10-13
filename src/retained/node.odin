package retained;

import fmt "core:fmt";
import strings "core:strings";

import helpers "../";
import types "../types";
import utils "../utils";

////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////// RETAINED API ///////////////////////////////////////////////
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
create_node :: proc (
    ctx:        ^types.Context,
    tag:        string,
    id:         types.Option(int)                   = nil,
    parent:     ^types.Node                         = nil,
    style:      map[string]types.Option(string)     = { },
    properties: map[string]types.Option(string)     = { },
    children:   map[types.Id]types.Node             = { },
    indent:     string                              = "  ") -> types.Node {
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
destroy_node :: proc (ctx: ^types.Context, id: types.Id, indent: string = "  ") -> types.NodeError {
    using types;
    using utils;

    assert(ctx != nil, "[ERR]:\t| Error destroying node: Context is nil!");

    level : LogLevel = into_debug(ctx.config["log_level"]);

    if level >= LogLevel.Verbose {
        fmt.printfln("[INFO]:{}| Destroying node [{}] ...", indent, id);
    }

    new_indent, _ := strings.concatenate({ indent, "  " });
    node_ptr := helpers.find_node(ctx, id, new_indent);
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
    nodes_to_delete_ordered := helpers.flatten_node(node_ptr);
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
        if len(node_to_delete.children) != 0 {
            delete_map(node_to_delete.children);
        }
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
attach_node :: proc (ctx: ^types.Context, node: types.Node, indent: string = "  ") -> types.NodeError {
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
        ctx.root = new_clone(node);
        new_node   = ctx.root^;
        ctx.last_node = ctx.root;

    } else if ctx.last_node != parent_ptr {
        new_indent, _ := strings.concatenate({ indent, "  " });
        parent_ptr = helpers.find_node(ctx, parent_ptr.id, new_indent);
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
            helpers.print_nodes(parent_ptr, new_indent);
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
detach_node :: proc (ctx: ^types.Context, id: types.Id, indent: string = "  ") -> types.Option(^types.Node) {
    using types;
    using utils;

    assert(ctx != nil, "[ERR]:\t| Error detaching node: Context is nil!");

    level : LogLevel = into_debug(ctx.config["log_level"]);
    if level >= LogLevel.Verbose {
        fmt.printfln("[INFO]:{}| Detaching [{}] from context tree ...", indent, id);
    }

    new_indent, _ := strings.concatenate({ indent, "  " });
    defer delete_string(new_indent);

    node_ptr := helpers.find_node(ctx, id, new_indent);

    if node_ptr == nil {
        if level >= LogLevel.Verbose {
            fmt.printfln("[WARN]:{}--- Cannot detach nil node, skipping ...", indent);
        }

        return none(^Node);
    }

    destroy_node(ctx, id, new_indent);

    if level >= LogLevel.Verbose {
        fmt.printfln("[INFO]:{}--- Done", indent);
    }

    return node_ptr;
}