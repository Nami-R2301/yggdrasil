#+feature dynamic-literals
package retained;

import fmt      "core:fmt";
import strings  "core:strings";

import ygg   "../";
import types "../types";
import utils "../utils";

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
    indent:     string                              = "  ") -> (types.Node, types.ContextError) {
    using types;
    using utils;

    if context.user_ptr == nil {
        return {}, ContextError.InvalidContext;
    }

    ctx: ^Context = cast(^Context)context.user_ptr;

    level : LogLevel = into_debug(ctx.config["log_level"]);
    if level >= LogLevel.Verbose {
        fmt.printf("[INFO]:{}| Creating node ({{ tag = '{}', id = {}, parent?: '{}' [{}] (%p)}}) ...", indent, tag, id,
        parent != nil ? parent.tag : "nil", parent != nil ? parent.id : 0, parent);
    }

    parent_node     := parent != nil ? parent : ctx.last_node;
    new_id: int     = unwrap_or(id, 0);
    will_overflow   := _check_id_overflow(new_id);

    if will_overflow && level >= LogLevel.Normal {
        fmt.printfln("[WARN]:{}| Node with ID [{}] will overflow if attached to tree! " +
        "Modify [Id]'s alias to be a bigger type if you need to attach more nodes.",
        indent, new_id);
    }

    if !is_some(id) && parent_node != nil {
        new_id = int(parent_node.id + Id(len(parent_node.children) + 1));
    }

    if level >= LogLevel.Verbose {
        fmt.println(" Done");
    }

    return Node {
        parent = parent_node,
        id = Id(new_id),
        tag = tag,
        children = children,
        style = style,
        user_data = user_data,
    }, ContextError.None;
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

    new_indent, _ := strings.concatenate({indent, "  "}, context.temp_allocator);
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
            delete_map(node_to_delete.children);
        }

        if len(node_to_delete.style) != 0 {
            delete_map(node_to_delete.style);
        }

        if node_to_delete.user_data != nil {
            free(node_to_delete.user_data);
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
attach_node :: proc (node: types.Node, indent: string = "  ") -> types.Error {
    using types;
    using utils;

    if context.user_ptr == nil {
        return ContextError.InvalidContext;
    }

    ctx: ^Context = cast(^Context)context.user_ptr;
    level : LogLevel = into_debug(ctx.config["log_level"]);

    parent_ptr : ^Node = node.parent != nil ? node.parent : ctx.last_node;
    new_node   : Node  = node;

    if level >= LogLevel.Verbose {
        fmt.printfln("[INFO]:{}| Attaching node [tag = '{}', id = {} under '{}'] ...", indent, node.tag, node.id,
        parent_ptr != nil ? parent_ptr.tag : "nil");
    }

    if parent_ptr == nil {
        ctx.root = new_clone(node, ctx.allocator);
        new_node   = ctx.root^;
        ctx.last_node = ctx.root;

    } else if ctx.last_node != parent_ptr {
        new_indent, _ := strings.concatenate({indent, "  "}, context.temp_allocator);
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
        ctx.root = new_clone(new_node, ctx.allocator);
        ctx.last_node = ctx.root;
    } else {
        new_node.parent = parent_ptr;
        if parent_ptr != nil {
            parent_ptr.children[node.id] = new_node;
            ctx.last_node = &parent_ptr.children[node.id];
        }
    }

    if level >= LogLevel.Verbose {
        new_indent, _ := strings.concatenate({indent, "  "}, context.temp_allocator);
        if parent_ptr != nil {
            ygg.print_nodes(parent_ptr, new_indent);
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

    new_indent, _ := strings.concatenate({ indent, "  " }, ctx.allocator);

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

// This function does NOT actually draw contents on the active framebuffer right away, it only compiles it and will
// be drawn on the next 'render_now()' call.
text :: proc (str: string, add_to: ^types.Node, indent: string = "  ") -> (text_node: types.Node, err: types.Error) {
    using types;

    fmt.printfln("[INFO]:{}| Preparing text glyphs for {} ... ", indent, str);

    assert(context.user_ptr != nil, "[ERR]:\tCannot prepare text: Context is nil");
    ctx := cast(^Context)context.user_ptr;

    box_vertices := cast(^[5]Vertex)add_to.user_data;
    if box_vertices == nil || size_of(box_vertices) != size_of(^[5]Vertex) {
        fmt.eprintfln("[ERR]: {}--- Cannot render text {}: Invalid box (add_to)", indent, str);
        return {}, RendererError.InvalidUserData;
    }

    new_indent, _ := strings.concatenate({indent, "  "}, context.temp_allocator);

    glyphs: [dynamic]Glyph = create_glyphs(str, &ctx.primary_font, 0, 0);
    ygg.push_data(&ctx.renderer.vbo, Data{ ptr = raw_data(glyphs), count = u64(len(glyphs)), size = size_of(Glyph)},
    indent = new_indent) or_return;

    text_node = create_node("text", parent = add_to, indent = new_indent) or_return;
    fmt.printfln("[INFO]:{}--- Done", indent);
    return text_node, RendererError.None;
}

// This function does NOT actually draw contents on the active framebuffer right away, it only compiles it and will
// be drawn on the next 'render_now()' call.
box :: proc (
    size_pixels: [2]u32             = {0, 0},
    offset: types.Option([2]u32)    = nil,  // Optional: Fallback to current cursor position if omitted
    z: f32                          = 0,
    color: [4]f32                   = {},
    roundness: f32                  = 0,
    indent: string                  = "  ") -> (types.Node, types.Error) {
    using types;
    using utils;

    if context.user_ptr == nil {
        fmt.printfln("[ERR]:{}| Error drawing box: Context is nil!", indent);
    }

    ctx := cast(^Context)context.user_ptr;

    if ctx.renderer == nil {
        fmt.eprintfln("[ERR]:{}--- Error drawing box: Renderer is nil!");
        return {}, RendererError.InvalidRenderer;
    }

    fmt.printfln("[INFO]:{}| Drawing box ... ", indent);
    offset: [2]u32 = unwrap_or(offset, ctx.cursor[0]);

    triangle_strip := [5]Vertex{
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
    }

    new_indent, _ := strings.concatenate({indent, "  "}, context.temp_allocator);

    vbo_error  := ygg.prepare_buffer(&ctx.renderer.vbo, Data { ptr = &triangle_strip, count = 5, size = size_of(Vertex) },
    allocator = ctx.allocator, indent = new_indent);
    if vbo_error != BufferError.None {
        fmt.eprintfln("[ERR]:{}--- Error drawing box: {}", vbo_error);
        return {}, vbo_error;
    }

    // Advance cursor
    ctx.cursor[0] += size_pixels[0];
    ctx.cursor[1] += size_pixels[1];


    fmt.printfln("[INFO]:{}--- Done", indent);
    return create_node("box", style = {
        "fill_color" = utils.into_str(color),
    }, user_data = new_clone(triangle_strip, ctx.allocator));
}