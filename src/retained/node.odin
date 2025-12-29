package retained;

import fmt      "core:fmt";
import strings  "core:strings";
import mem      "core:mem";
import runtime  "base:runtime";

import core   "../";
import types "../types";
import utils "../utils";

// Create and serialize a box node for rendering. Each box is 5 vertices since we are rendering using triangle strips.
// This is the equivalent of a div or container in HTML.
box :: proc "c" (
    ctx:         runtime.Context,
    parent:      ^types.Node,
    style:       map[string]types.Option(string) = {},
    indent:      string = "  ") -> types.Node {
    using types;

    context = ctx;
    fmt.printf("[INFO]:{}| Creating box node ... ", indent);

    core_ctx := cast(^Context)context.user_ptr;
    assert_contextless(core_ctx != nil, "[ERR]:\tCannot create box node: Context is nil!");
    assert_contextless(core_ctx.renderer != nil, "[ERR]:\tCannot create box node: Renderer is nil!");

    position_pixels: [2]u32 = utils.into_measure(style["position"]);
    size_pixels: [2]u32     = utils.into_measure(style["box-size"]);

    z_index: u16        = utils.into_z_index(style["z-index"]);
    fill_color: [4]f32  = utils.into_color(style["box-color"]);

    triangle_strip, mem_error := new_clone([5]Vertex{
    // Top Left (Red)
        {
            position     = { f32(position_pixels.x), f32(position_pixels.y), f32(z_index) },
            color        = fill_color,
        },
        // Bottom Left (Green)
        {
            position     = { f32(position_pixels.x), f32(position_pixels.y + size_pixels.y), f32(z_index) },
            color        = fill_color,
        },
        // Bottom Right (Blue)
        {
            position     = { f32(position_pixels.x + size_pixels.x), f32(position_pixels.y + size_pixels.y), f32(z_index) },
            color        = fill_color,
        },
        // Top Left (Red)
        {
            position     = { f32(position_pixels.x), f32(position_pixels.y), f32(z_index) },
            color        = fill_color,
        },
        // Top Right
        {
            position     = { f32(position_pixels.x + size_pixels.x), f32(position_pixels.y), f32(z_index) },
            color        = fill_color,
        },
    }, allocator = ctx.allocator);
    assert(mem_error == mem.Allocator_Error.None, "[ERR]:\tCannot create box node: Out of memory (just buy more ram)");

    // Advance cursor
    core_ctx.cursor[0] += size_pixels.x;
    core_ctx.cursor[1] += size_pixels.y;

    new_indent, mem_err := strings.concatenate({indent, "  "}, context.temp_allocator);
    assert(mem_err == mem.Allocator_Error.None, "[ERR]:\tCannot create box node: Out of memory (just buy more ram)");

    box_node := core.create_node(ctx, "box", style = style, indent = new_indent);

    box_node.user_data, mem_err = new_clone(Data { ptr = &triangle_strip, count = 5, size = size_of(Vertex) }, ctx.allocator);
    assert(mem_err == mem.Allocator_Error.None, "[ERR]:\tCannot create box node: Out of memory (just buy more ram)");

    fmt.println("Done");
    return box_node;
}

// Create and serialize a text box node for rendering. Pre-computes all glyphs required to the text to appear.
// This create text INSIDE of a box, but will only count as ONE node in the tree to avoid node pollution.
text :: proc "c" (
    ctx:            runtime.Context,
    content:        string,
    parent_ptr:     ^types.Node = nil,  // Where to attach it to in the tree
    box_ptr:        ^types.Node = nil,  // Which box to put it into. If omitted, create a new one
    style:          map[string]types.Option(string) = {},
    do_attach:      bool = true,  // Immediately attach it upon creation
    indent:         string = "  ") -> types.Node {
    using types;

    context = ctx;
    fmt.printfln("[INFO]:{}| Creating text glyphs for '{}' ... ", indent, content);

    core_ctx := cast(^Context)context.user_ptr;
    assert_contextless(core_ctx != nil, "[ERR]:\tCannot create text glyphs: Context is nil!");
    assert_contextless(core_ctx.renderer != nil, "[ERR]:\tCannot create text glyphs: Renderer is nil!");

    new_indent, mem_err := strings.concatenate({indent, "  "}, context.temp_allocator);
    assert_contextless(mem_err == mem.Allocator_Error.None, "[ERR]:\tCannot create text node: Out of memory (just buy more ram)");

    box_node: Node = box_ptr != nil ? box_ptr^ : box(ctx, parent_ptr, style, indent = new_indent);
    box_vertices := cast(^[5]Vertex)box_node.user_data;
    if box_vertices == nil || size_of(box_vertices) != size_of(^[5]Vertex) {
        fmt.eprintfln("[ERR]: {}--- Cannot create text glyphs {}: Invalid box (add_to)", indent, content);
        panic("Invalid text data");
    }

    text_node := core.create_node(ctx, "text", parent = parent_ptr, indent = new_indent);
    vertices: [dynamic]Vertex = core.create_glyphs(content, i32(text_node.id), &core_ctx.primary_font, 0, 0, allocator = ctx.allocator);

    text_node.user_data, mem_err = new_clone(Data {
        ptr = raw_data(vertices), count = u64(len(vertices)), size = size_of(Vertex)
    }, ctx.allocator);
    assert(mem_err == mem.Allocator_Error.None, "[ERR]:\tCannot create text node: Out of memory (just buy more ram)");

    if do_attach {
        core.attach_node(ctx, text_node, new_indent);
    }

    fmt.printfln("[INFO]:{}--- Done", indent);
    return text_node;
}