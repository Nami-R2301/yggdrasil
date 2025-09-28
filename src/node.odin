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

    parent : ^types.Node = parent != nil ? parent : ctx.last_node;

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
    node_ptr := _find_node(ctx, id, new_indent);
    delete_string(new_indent);

    if node_ptr == nil {
        if level >= types.LogLevel.Normal {
            fmt.eprintfln("[ERR]:{}--- Error destroying node: types.Node [{}] not found", indent, id);
        }
        return types.ContextError.NodeNotFound;
    }

    // Stack for DFS traversal, implemented with a dynamic array.
    to_visit := make([dynamic]^types.Node);
    defer delete(to_visit);

    // List to store the nodes in post-order (children first).
    nodes_to_delete_ordered := make([dynamic]^types.Node);
    defer delete(nodes_to_delete_ordered);

    append(&to_visit, node_ptr);

    for len(to_visit) > 0 {
        // Pop a node from our visit stack.
        node := pop(&to_visit);

        // Append the node to our results list. We will reverse it later.
        append(&nodes_to_delete_ordered, node);

        // Add all children to the visit stack. They will be processed next.
        for _, &child in node.children {
            append(&to_visit, &child);
        }
    }

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

    if level >= types.LogLevel.Verbose {
        fmt.printfln("[INFO]:{}--- Done", indent);
    }

    return types.ContextError.None;
}


_find_node :: proc (ctx: ^types.Context, id: types.Id, indent: string = "  ") -> ^types.Node {
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

    return found_ptr;
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
                return inner_node_ptr;
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

    parent_ptr : ^types.Node = node.parent != nil ? node.parent : ctx.last_node;
    new_node   : types.Node  = node;

    if level >= types.LogLevel.Verbose {
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
        parent_ptr = _find_node(ctx, parent_ptr.id, new_indent);
        delete_string(new_indent);

        if parent_ptr == nil {
            if level >= types.LogLevel.Normal {
                fmt.eprintfln("[WARN]:{}--- Node parent is nil, attaching to root instead ...", indent);
            }

            parent_ptr = ctx.root;
        }
    }

    new_node.parent = parent_ptr;
    if parent_ptr != nil {
        parent_ptr.children[node.id] = new_node;
        ctx.last_node = &parent_ptr.children[node.id];
    }

    if level >= types.LogLevel.Verbose {
        if parent_ptr != nil {
            new_indent, _ := strings.concatenate({ indent, "  " });
            print_nodes(parent_ptr, new_indent);
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
    defer delete_string(new_indent);

    node_ptr := _find_node(ctx, id, new_indent);

    if node_ptr == nil {
        if level >= types.LogLevel.Verbose {
            fmt.printfln("[WARN]:{}--- Cannot detach nil node, skipping ...", indent);
        }

        return utils.none(^types.Node);
    }

    _destroy_node(ctx, id, new_indent);

    if level >= types.LogLevel.Verbose {
        fmt.printfln("[INFO]:{}--- Done", indent);
    }

    return node_ptr;
}
