package yggdrasil;

import "core:fmt";
import "core:strings";
import types "types";
import utils "utils";

////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////// HIGH LEVEL API /////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////

begin_node :: proc () {
    panic("Not Implemented")
}


end_node :: proc () {
    panic("Not Implemented")
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////// LOW LEVEL API //////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Low-level API to create a custom UI node, to be attached onto the tree later on. This is normally intended to be abstracted away from the programmer
// behind high-level API entrypoints like 'begin_node'. One might use this function to wait and prevent the automatic rendering mechanisms provided
// and performed by 'begin_node', i.e. for a temporary node that does not live long enough to reach end of frame (Cleaned up with 'destroy_node(...)').
//
// Another common use-case would be to use this newly-created node from this function to only store and hold information that might happen within a cycle,
// without expanding the tree unnecessarily (data-nodes).
//
// @lifetime:           This function does NOT cleanup after itself like the high-level API, hence 'destroy_node(..)' is needed for each corresponding 'create_node' in the frame's scope.
// @param ctx:          The tree containing all nodes to be processed.
// @param id:           Unique identifier to lookup node when processing.
// @param tag:          Which tag identifier will be used to lookup the node in the map. Tag needs to be unique, unless you are planning to override the existing node.
// @param style:        CSS-like style mapping to be applied upon rendering on each frame.
// @param properties:   Data map to store information related to the node as well as override default ones (alt, disabled, type, etc...) which will mutate the node's functionality.
// @param children:     The leaf nodes related under this one,
_create_node :: proc (
    ctx:        ^types.Context,
    id:         types.Id, tag: string,
    parent:     ^types.Node = nil,
    style:      map[types.Id]types.Option(string) = { },
    properties: map[types.Id]types.Option(string) = { },
    children:   map[types.Id]types.Node = { },
    indent:     string = "  "
) -> types.Node {
    assert(ctx != nil, "[ERR]:\t| Error creating node: Context is nil!");

    level : types.LogLevel = utils.into_debug(ctx.config["log_level"]);
    if level >= types.LogLevel.Verbose {
        fmt.printf("[INFO]:{}| Creating node ({{ tag = '{}', id = {}, parent?: '{}' [{}] (%p)}}) ...", indent, tag, id,
        parent != nil ? parent.tag : "nil", parent != nil ? parent.id : 0, parent);
    }

    last_node: ^types.Node = nil;

    if utils.is_some(ctx.last_node) {
        node: types.Node = utils.unwrap(ctx.last_node);
        last_node = &node;
    }

    parent : ^types.Node = parent != nil ? parent : last_node;
    if level >= types.LogLevel.Verbose {
        fmt.println(" Done");
    }

    node := types.Node {
        parent = parent,
        id = id,
        tag = tag,
        children = children,
        style = style,
        properties = properties
    };

    return node;
}

_reset_node :: proc (ctx: ^types.Context, id: types.Id, indent: string = "  ") -> types.ContextError {
    assert(ctx != nil, "[ERR]:\t| Error resetting node: Context is nil!");
    panic("Not Implemented");
}

// Deallocate a leaf and all of its children
_destroy_node :: proc (ctx: ^types.Context, id: types.Id, indent: string = "  ") -> types.ContextError {
    assert(ctx != nil, "[ERR]:\t| Error destroying node: Context is nil!");

    level : types.LogLevel = utils.into_debug(ctx.config["log_level"]);

    if level >= types.LogLevel.Verbose {
        fmt.printfln("[INFO]:{}| Destroying node [{}] ...", indent, id);
    }

    new_indent, _ := strings.concatenate({ indent, "  " });
    node_opt := _find_node(ctx, id, new_indent);

    if !utils.is_some(node_opt) {
        if level >= types.LogLevel.Normal {
            fmt.eprintfln("[ERR]:{}--- Error destroying node: types.Node [{}] not found", indent, id);
        }
        delete_string(new_indent);
        return types.ContextError.NodeNotFound;
    }

    node := utils.unwrap(node_opt);

    // Cleanup after ourselves
    for child_id, _ in node.children {
        _ = _destroy_node(ctx, child_id, indent);
    }

    delete_string(new_indent);
    delete_map(node.children);

    if level >= types.LogLevel.Verbose {
        fmt.printfln("[INFO]:{}--- Done", indent);
    }

    return types.ContextError.None;
}


_find_node :: proc (ctx: ^types.Context, id: types.Id, indent: string = "  ") -> types.Option(^types.Node) {
    assert(ctx != nil, "[ERR]:\t| Error finding node: Context is nil!");

    log_level := utils.into_debug(ctx.config["log_level"]);

    if log_level >= types.LogLevel.Verbose {
        fmt.printf("[INFO]:{}| Searching for node id [{}] in context tree ...", indent, id);
    }

    if ctx.root == nil {
        if log_level >= types.LogLevel.Verbose {
            fmt.println(" Done");
        }
        return utils.none(^types.Node);
    }

    if id == ctx.root.id {
        if log_level >= types.LogLevel.Verbose {
            fmt.println(" Done");
        }

        return utils.some(ctx.root);
    }

    found_ptr := _find_child(ctx.root, id);

    if found_ptr == nil {
        if log_level >= types.LogLevel.Verbose {
            fmt.printfln("\n[WARN]:{}--- Node not found", indent);
        }

        return found_ptr;
    }

    if log_level >= types.LogLevel.Verbose {
        fmt.println(" Done");
    }

    return found_ptr != nil ? utils.some(found_ptr) : utils.none(^types.Node);
}


@(private)
_find_child :: proc (current_node_ptr: ^types.Node, id: types.Id) -> ^types.Node {
    if current_node_ptr != nil {
        for child_id, &child_ptr in current_node_ptr.children {
            if child_id == id {
                return &child_ptr;
            }

            if &child_ptr != nil && len(child_ptr.children) > 0 {
                inner_node_ptr := _find_child(&child_ptr, id);
                if inner_node_ptr.parent != nil {
                    return inner_node_ptr;
                }
            }
        }
    }

    return nil;
}

_get_tree_depth :: proc (root: ^types.Node) -> types.Id {
    if root == nil {
        return 0;
    }

    depth : types.Id = types.Id(len(root.children));

    for id, &leaf in root.children {
        if leaf.parent != nil {
            depth += _get_tree_depth(&leaf);
        }
    }

    return depth;
}

// Low-level API to attach a node to the current ui tree. Benefit of this function over its high-level counterparts 'begin_node(...)' is the ability to explicitely
// have control over when this node gets queued in the rendering pipeline, in case you needed to delay rendering after pre-processing, since the former will queue the
// node immediately without any say in it. Once a node is attached this way, only 'detach_node(...)' can remove it from the pipeline and NOT its end_... counterpart
// like the high-level API.
//
// @param ctx:    The current tree where we want to attach this node to. 
// @param node:   Which node is to be added to the tree
_attach_node :: proc (ctx: ^types.Context, node: types.Node, indent: string = "  ") -> types.ContextError {
    assert(ctx != nil, "[ERR]:\t| Error attaching node: Context is nil!");

    level : types.LogLevel = utils.into_debug(ctx.config["log_level"]);
    last_node: ^types.Node = nil;

    if utils.is_some(ctx.last_node) {
        node: types.Node = utils.unwrap(ctx.last_node);
        last_node = &node;
    }

    parent : ^types.Node = node.parent != nil ? node.parent : last_node;

    if level >= types.LogLevel.Verbose {
        fmt.printfln("[INFO]:{}| Attaching node [tag = '{}', id = {} under '{}'] ...", indent, node.tag, node.id, parent != nil ? parent.tag : "root");
    }

    if parent == nil {
        ctx.root = new_clone(node);
        ctx.last_node = utils.some(ctx.root^);
    } else {
        new_indent, _ := strings.concatenate({ indent, "  " });
        parent_opt := _find_node(ctx, parent.id, new_indent);
        delete_string(new_indent);

        if !utils.is_some(parent_opt) {
            if level >= types.LogLevel.Normal {
                fmt.eprintfln("[ERR]:{}--- Error when attaching node: Parent not found", indent);
            }
            return types.ContextError.NodeNotFound;
        }

        parent = utils.unwrap(parent_opt);
        new_node := node;
        new_node.parent = parent;
        parent.children[node.id] = new_node;

        ctx.last_node = utils.some(new_node);
    }

    if level >= types.LogLevel.Verbose {
        if parent != nil {
            new_indent, _ := strings.concatenate({ indent, "  " });
            print_nodes(parent, new_indent);
            delete_string(new_indent);
        }

        fmt.printfln("[INFO]:{}--- Done (%p)", indent, ctx.last_node);
    }

    return types.ContextError.None
}

// Low-level API to detach a node in the current ui tree. Benefit of this function over its high-level counterparts 'end_node(...)' is the ability to explicitely
// have control over when this node gets dequeued from the rendering pipeline, in case you needed to delay rendering after pre-processing, since the former will dequeue the
// node immediately without any say in it. This will also detach children within the leaf, meaning it will remove all of the leaf's children
// as well from the context tree if it contains children.
//
// @param ctx:    The current tree where we want to attach this node to.
// @param node:   Which node is to be added to the tree
_detach_node :: proc (ctx: ^types.Context, id: types.Id, indent: string = "  ") -> types.Option(^types.Node) {
    assert(ctx != nil, "[ERR]:\t| Error detaching node: Context is nil!");

    level : types.LogLevel = utils.into_debug(ctx.config["log_level"]);
    if level >= types.LogLevel.Verbose {
        fmt.printfln("[INFO]:{}| Detaching [{}] from context tree ...", indent, id);
    }

    new_indent, _ := strings.concatenate({ indent, "  " });
    node_opt := _find_node(ctx, id, new_indent);

    if !utils.is_some(node_opt) {
        return utils.none(^types.Node);
    }

    node := utils.unwrap(node_opt);

    if node == nil {
        if level >= types.LogLevel.Verbose {
            fmt.printfln("[WARN]:{}--- Cannot detach nil node, skipping ...", indent);
        }

        return utils.none(^types.Node);
    }

    _destroy_node(ctx, id, new_indent);
    delete_string(new_indent);

    if level >= types.LogLevel.Verbose {
        fmt.printfln("[INFO]:{}--- Done", indent);
    }

    return node;
}
