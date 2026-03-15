package retained;

import fmt      "core:fmt";
import strings  "core:strings";
import mem      "core:mem";

import core   "../";
import types  "../types";
import utils  "../utils";

// Create and serialize a box node for rendering. Each box is 5 vertices since we are rendering using triangle strips.
// This is the equivalent of a div or container in HTML.
@(export, link_prefix="ygg_rt_")
box :: proc "c" (
    ctx:         ^types.Context,
    parent:      ^types.Node,
    style:       map[string]Maybe(string) = {},
    indent:      cstring = "  ") -> types.Node {
    assert_contextless(ctx != nil, "[ERR]:\tCannot create box node: Context is nil!");
    context = ctx^._context;
    fmt.printf("[INFO]:{}| Creating box node ... ", indent);

    assert_contextless(ctx.renderer != nil, "[ERR]:\tCannot create box node: Renderer is nil!");

    position_pixels: [2]u32 = utils.into_measure(style["position"]);
    size_pixels: [2]u32     = utils.into_measure(style["box-size"]);

    z_index: u16        = utils.into_z_index(style["z-index"]);
    fill_color: [4]f32  = utils.into_color(style["box-color"]);

    triangle_strip, mem_error := new_clone([5]types.Vertex{
        // Top Left
        {
            position     = { f32(position_pixels.x), f32(position_pixels.y), f32(z_index) },
            color        = fill_color,
        },
        // Bottom Left
        {
            position     = { f32(position_pixels.x), f32(position_pixels.y + size_pixels.y), f32(z_index) },
            color        = fill_color,
        },
        // Bottom Right
        {
            position     = { f32(position_pixels.x + size_pixels.x), f32(position_pixels.y + size_pixels.y), f32(z_index) },
            color        = fill_color,
        },
        // Top Left
        {
            position     = { f32(position_pixels.x), f32(position_pixels.y), f32(z_index) },
            color        = fill_color,
        },
        // Top Right
        {
            position     = { f32(position_pixels.x + size_pixels.x), f32(position_pixels.y), f32(z_index) },
            color        = fill_color,
        },
    });
    assert(mem_error == mem.Allocator_Error.None, "[ERR]:\tCannot create box node: Out of memory (just buy more ram)");

    // Advance cursor
    ctx.cursor[0] += size_pixels.x;
    ctx.cursor[1] += size_pixels.y;

    new_indent, mem_err := strings.concatenate({string(indent), "  "}, context.temp_allocator);
    c_indent := cstring(raw_data(new_indent));
    assert(mem_err == mem.Allocator_Error.None, "[ERR]:\tCannot create box node: Out of memory (just buy more ram)");

    box_node := core.create_node(ctx, "box", style = style, indent = c_indent);

    box_node.user_data, mem_err = new_clone(types.Data { ptr = &triangle_strip, count = 5, size = size_of(types.Vertex) });
    assert(mem_err == mem.Allocator_Error.None, "[ERR]:\tCannot create box node: Out of memory (just buy more ram)");

    fmt.println("Done");
    return box_node;
}

// Create and serialize a text box node for rendering. Pre-computes all glyphs required to the text to appear.
// This create text INSIDE of a box, but will only count as ONE node in the tree to avoid node pollution.
@(export, link_prefix="ygg_rt_")
text :: proc "c" (
    ctx:            ^types.Context,
    content:        string,
    parent_ptr:     ^types.Node = nil,  // Where to attach it to in the tree
    box_ptr:        ^types.Node = nil,  // Which box to put it into. If omitted, create a new one
    style:          map[string]Maybe(string) = {},
    do_attach:      bool = true,  // Immediately attach it upon creation
    indent:         cstring = "  ") -> types.Node {
    assert_contextless(ctx != nil, "[ERR]:\tCannot create text glyphs: Context is nil!");
    context = ctx^._context;
    fmt.printfln("[INFO]:{}| Creating text glyphs for '{}' ... ", indent, content);

    assert_contextless(ctx.renderer != nil, "[ERR]:\tCannot create text glyphs: Renderer is nil!");

    new_indent, mem_err := strings.concatenate({string(indent), "  "}, context.temp_allocator);
    assert_contextless(mem_err == mem.Allocator_Error.None, "[ERR]:\tCannot create text node: Out of memory (just buy more ram)");
    c_indent := cstring(raw_data(new_indent));

    box_node: types.Node = box_ptr != nil ? box_ptr^ : box(ctx, parent_ptr, style, indent = c_indent);
    box_vertices := cast(^[5]types.Vertex)box_node.user_data;
    if box_vertices == nil || size_of(box_vertices) != size_of(^[5]types.Vertex) {
        fmt.eprintfln("[ERR]: {}--- Cannot create text glyphs {}: Invalid box (add_to)", indent, content);
        panic("Invalid text data");
    }

    text_node := core.create_node(ctx, "text", parent = parent_ptr, indent = c_indent);
    vertices: [dynamic]types.Vertex = core.create_glyphs(content, i32(text_node.id), &ctx.primary_font, 0, 0);

    text_node.user_data, mem_err = new_clone(types.Data {
        ptr = raw_data(vertices), count = u64(len(vertices)), size = size_of(types.Vertex)
    });
    assert(mem_err == mem.Allocator_Error.None, "[ERR]:\tCannot create text node: Out of memory (just buy more ram)");

    if do_attach {
        core.attach_node(ctx, text_node, c_indent);
    }

    fmt.printfln("[INFO]:{}--- Done", indent);
    return text_node;
}