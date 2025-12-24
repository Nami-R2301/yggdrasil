#+feature dynamic-literals
package retained;

import fmt      "core:fmt";
import strings  "core:strings";

import ygg   "../";
import types "../types";
import utils "../utils"
import mem "core:mem";

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
    tag:        string,
    id:         types.Option(int)                   = nil,
    parent:     ^types.Node                         = nil,
    style:      map[string]types.Option(string)     = { },
    children:   map[types.Id]types.Node             = { },
    user_data:  rawptr                              = nil,
    indent:     string                              = "  ") -> types.Node {
    using types;
    using utils;

    assert(context.user_ptr != nil, "[ERR]:{}\tCannot create node: Context is nil. Did you forget to set " +
    "context.user_part to '&ctx' ?");
    ctx := cast(^Context)context.user_ptr;

    assert(ctx != nil, "[ERR]:\tCannot create node: Context is nil. Did you forget to call 'create_context(...)' ?");

    level : LogLevel = into_debug(ctx.config["log_level"]);
    if level >= LogLevel.Verbose {
        fmt.printf("[INFO]:{}| Creating node ({{ tag = '{}', id = {}, parent?: '{}' [{}] (%p)}}) ...", indent, tag, id,
        parent != nil ? parent.tag : "nil", parent != nil ? parent.id : 0, parent);
    }

    parent_node     := parent != nil ? parent : ctx.last_node;
    new_id: int     = unwrap_or(id, 0);
    will_overflow   := _check_id_overflow(new_id);

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
destroy_node :: proc (id: types.Id, indent: string = "  ") -> types.Error {
    using types;
    using utils;

    if context.user_ptr == nil {
        return ContextError.InvalidContext;
    }

    ctx: ^Context = cast(^Context)context.user_ptr;
    level : LogLevel = into_debug(ctx.config["log_level"]);

    if level >= LogLevel.Verbose {
        fmt.printfln("[INFO]:{}| Destroying node [{}] ...", indent, id);
    }

    new_indent := strings.concatenate({indent, "  "}, context.temp_allocator) or_return;
    node_ptr := ygg.find_node(id, new_indent);

    if node_ptr == nil {
        if level >= LogLevel.Normal {
            fmt.eprintfln("[ERR]: {}--- Error destroying node: Node [{}] not found", indent, id);
        }
        return NodeError.NodeNotFound;
    }

    nodes_to_delete_ordered := ygg.flatten_node(node_ptr);

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
            delete_map(node_to_delete.children) or_return;
        }

        if len(node_to_delete.style) != 0 {
            delete_map(node_to_delete.style) or_return;
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
attach_node :: proc (node: types.Node, indent: string = "  ") {
    using types;
    using utils;

    assert(context.user_ptr != nil, "[ERR]:\tCannot attach node: Context is nil. Did you forget to forget to call " +
    "'create_context(...)' or to assign it to 'context.user_ptr' ?");

    ctx: ^Context = cast(^Context)context.user_ptr;
    assert(context.user_ptr != nil, "[ERR]:\tCannot attach node: Context is nil. Did you forget to forget to call " +
    "'create_context(...)' ?");

    level : LogLevel = into_debug(ctx.config["log_level"]);

    parent_ptr : ^Node = node.parent != nil ? node.parent : ctx.last_node;
    new_node   : Node  = node;
    mem_err: mem.Allocator_Error;

    if level >= LogLevel.Verbose {
        fmt.printfln("[INFO]:{}| Attaching node [tag = '{}', id = {} under '{}'] ...", indent, node.tag, node.id,
        parent_ptr != nil ? parent_ptr.tag : "nil");
    }

    if parent_ptr == nil {
        ctx.root, mem_err = new_clone(node, ctx.allocator);
        assert(mem_err == mem.Allocator_Error.None, "[ERR]:\tCannot attach node: Out of memory (buy more ram)");
        new_node   = ctx.root^;
        ctx.last_node = ctx.root;

    } else if ctx.last_node != parent_ptr {
        new_indent, mem_error := strings.concatenate({indent, "  "}, context.temp_allocator);
        assert(mem_error == mem.Allocator_Error.None, "[ERR]:\tCannot attach node: Out of memory (buy more ram)");

        parent_ptr = ygg.find_node(parent_ptr.id, new_indent);

        if parent_ptr == nil {
            if level >= LogLevel.Normal {
                fmt.eprintfln("[WARN]:{}--- Node parent is nil, attaching to root instead ...", indent);
            }

            parent_ptr = ctx.root;
        }
    }

    if parent_ptr != nil && new_node.id == parent_ptr.id {
        fmt.printfln("[WARN]:{}| Overwriting root, setting '{}' as new root ...", indent, node.tag);
        free(ctx.root, ctx.allocator);
        ctx.root, mem_err = new_clone(new_node, ctx.allocator);
        assert(mem_err == mem.Allocator_Error.None, "[ERR]:\tCannot attach node: Out of memory (buy more ram)");

        ctx.last_node = ctx.root;
    } else {
        new_node.parent = parent_ptr;
        if parent_ptr != nil {
            parent_ptr.children[node.id] = new_node;
            ctx.last_node = &parent_ptr.children[node.id];
        }
    }

    if level >= LogLevel.Verbose {
        new_indent, mem_error := strings.concatenate({indent, "  "}, context.temp_allocator);
        assert(mem_error == mem.Allocator_Error.None, "[ERR]:\tCannot attach node: Out of memory (buy more ram)");

        if parent_ptr != nil {
            ygg.print_nodes(parent_ptr, new_indent);
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
detach_node :: proc (id: types.Id, indent: string = "  ") -> types.Option(^types.Node) {
    using types;
    using utils;

    if context.user_ptr == nil {
        return none(^Node);
    }

    ctx: ^Context = cast(^Context)context.user_ptr;

    level : LogLevel = into_debug(ctx.config["log_level"]);
    if level >= LogLevel.Verbose {
        fmt.printfln("[INFO]:{}| Detaching [{}] from context tree ...", indent, id);
    }

    new_indent, err := strings.concatenate({ indent, "  " }, ctx.allocator);
    if err != mem.Allocator_Error.None {
        fmt.eprintfln("[ERR]:{} --- Error detaching [{}] from context tree:", indent, id, err);
        return none(^Node);
    }

    node_ptr := ygg.find_node(id, new_indent);

    if node_ptr == nil {
        if level >= LogLevel.Verbose {
            fmt.printfln("[WARN]:{}--- Cannot detach nil node, skipping ...", indent);
        }

        return none(^Node);
    }

    destroy_node(id, indent = new_indent);

    if level >= LogLevel.Verbose {
        fmt.printfln("[INFO]:{}--- Done", indent);
    }

    return node_ptr;
}

// Create and serialize a text node for rendering. Pre-computes all glyphs required to the text to appear.
text :: proc (
    str: string,
    add_to: ^types.Node,
    indent: string = "  ") -> types.Node {
    using types;

    fmt.printf("[INFO]:{}| Creating text glyphs for '{}' ... ", indent, str);

    assert(context.user_ptr != nil, "[ERR]:\tCannot create text glyphs: Context is nil!");
    ctx := cast(^Context)context.user_ptr;
    assert(ctx != nil && ctx.renderer != nil, "[ERR]:\tCannot create text glyphs: Renderer is nil!");

    box_vertices := cast(^[5]Vertex)add_to.user_data;
    if box_vertices == nil || size_of(box_vertices) != size_of(^[5]Vertex) {
        fmt.eprintfln("[ERR]: {}--- Cannot create text glyphs {}: Invalid box (add_to)", indent, str);
        panic("Invalid text data");
    }

    new_indent, mem_err := strings.concatenate({indent, "  "}, context.temp_allocator);
    assert(mem_err == mem.Allocator_Error.None, "[ERR]:\tCannot create box node: Out of memory (just buy more ram)");

    text_node := create_node("text", parent = add_to, indent = new_indent);
    vertices: [dynamic]Vertex = create_glyphs(str, i32(text_node.id), &ctx.primary_font, 0, 0, allocator = ctx.allocator);

    text_node.user_data, mem_err = new_clone(Data {
        ptr = raw_data(vertices), count = u64(len(vertices)), size = size_of(Vertex)
    }, ctx.allocator);
    assert(mem_err == mem.Allocator_Error.None, "[ERR]:\tCannot create box node: Out of memory (just buy more ram)");

    fmt.println("Done", indent);
    return text_node;
}

// Create and serialize a box node for rendering. Each box is 5 vertices since we are rendering using triangle strips.
box :: proc (
    size_pixels: [2]u32             = {0, 0},
    offset: types.Option([2]u32)    = nil,  // Optional: Fallback to current cursor position if omitted
    z: f32                          = 0,
    color: [4]f32                   = {},
    roundness: f32                  = 0,
    indent: string                  = "  ") -> types.Node {
    using types;
    using utils;

    fmt.printf("[INFO]:{}| Creating box node ... ", indent);

    assert(context.user_ptr != nil, "[ERR]:\tCannot create box node: Context is nil!");
    ctx := cast(^Context)context.user_ptr;
    assert(ctx != nil && ctx.renderer != nil, "[ERR]:\tCannot create box node: Renderer is nil!");

    offset: [2]u32 = unwrap_or(offset, ctx.cursor[0]);
    triangle_strip, mem_error := new_clone([5]Vertex{
    // Top Left (Red)
        {
            position     = { f32(offset.x), f32(offset.y), 0.0 },
            color        = color,
        },
        // Bottom Left (Green)
        {
            position     = { f32(offset.x), f32(offset.y) + f32(size_pixels[1]), 0.0 },
            color        = color,
        },
        // Bottom Right (Blue)
        {
            position     = { f32(offset.x) + f32(size_pixels[0]), f32(offset.y) + f32(size_pixels[1]), 0.0 },
            color        = color,
        },
        // Top Left (Red)
        {
            position     = { f32(offset.x), f32(offset.y), 0.0 },
            color        = color,
        },
        // Top Right
        {
            position     = { f32(offset.x) + f32(size_pixels[0]), f32(offset.y), 0.0 },
            color        = color,
        },
    }, allocator = ctx.allocator);
    assert(mem_error == mem.Allocator_Error.None, "[ERR]:\tCannot create box node: Out of memory (just buy more ram)");

    // Advance cursor
    ctx.cursor[0] += size_pixels[0];
    ctx.cursor[1] += size_pixels[1];

    new_indent, mem_err := strings.concatenate({indent, "  "}, context.temp_allocator);
    assert(mem_err == mem.Allocator_Error.None, "[ERR]:\tCannot create box node: Out of memory (just buy more ram)");

    box_node := create_node("box", style = {
        "fill_color" = utils.into_str(color),
    }, indent = new_indent);

    box_node.user_data, mem_err = new_clone(Data { ptr = &triangle_strip, count = 5, size = size_of(Vertex) }, ctx.allocator);
    assert(mem_err == mem.Allocator_Error.None, "[ERR]:\tCannot create box node: Out of memory (just buy more ram)");

    fmt.println("Done");
    return box_node;
}