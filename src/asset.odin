package ygg;

import fmt      "core:fmt";
import os       "core:os/os2";
import mem      "core:mem";
import runtime  "base:runtime";

import ttf      "vendor:stb/truetype";
import gl       "vendor:OpenGL";

import types    "types";

@(export, link_prefix="ygg_")
init_font :: proc "c" (
    ctx:        ^types.Context,
    font_name:  cstring = "./res/fonts/default/JetBrainsMono-Regular.ttf",
    indent:     cstring = "  ") -> types.Error {
    assert_contextless(ctx != nil, "[ERR]:\tCannot init font: Context is nil");
    font := load_font(font_name, indent, ctx._context.allocator);

    // Bake the letters ' ' (32) through '~' (126) into the bitmap
    // This fills 'font_bitmap' with pixels and 'cdata' with coordinate info
    ttf.BakeFontBitmap(
        raw_data(font.bytes), 0,  // Font data
        f32(font.height_pixels),
        raw_data(font.font_bitmap[:]), // Output bitmap buffer
        512, 512, // Bitmap width/height
        ' ', // First char
        '~' - ' ', // Char count
        raw_data(font.cdata[:])  // Output character data
    );

    tex_id: u32 = 0;
    gl.GenTextures(1, &tex_id);
    gl.BindTexture(gl.TEXTURE_2D, tex_id);
    font.texture_id = tex_id;

    // GL_RED is used because we only have 1 byte per pixel (Alpha/Grayscale)
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RED, 512, 512, 0, gl.RED, gl.UNSIGNED_BYTE, raw_data(font.font_bitmap[:]));
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);

    ctx.primary_font = font;
    return types.FontError.None;
}

@(export, link_prefix="ygg_")
load_font :: proc "c" (
    path:       cstring,
    indent:     cstring = "  ",
    allocator:  mem.Allocator) -> types.Font {
    context = runtime.default_context();

    fmt.printf("[INFO]:{}| Loading font file {} ... ", indent, path);
    bytes, err := os.read_entire_file_from_path(string(path), allocator);
    if err != runtime.Allocator_Error.None {
        fmt.eprintfln("[ERR]:{} --- Cannot load font file {}: {}", indent, path, err);
        panic("Invalid font file");
    }

    font_info: ttf.fontinfo = {};
    if !ttf.InitFont(&font_info, raw_data(bytes), 0) {
        fmt.eprintfln("[ERR]:{} --- Cannot load font file {}: Cannot init TTF font struct", indent, path);
        panic("Invalid font file");
    }

    font := types.Font{
        width_pixels = 16,
        height_pixels = 16,
        bytes = bytes,
        font_bitmap = make([]u8, 512 * 512, allocator),
        cdata = make([]ttf.bakedchar, 96, allocator)
    };

    fmt.println("Done");
    return font;
}

// Helper to pack two 16-bit floats (0.0-1.0) into one 32-bit float
pack_uv :: proc(u, v: f32) -> f32 {
// Convert 0.0-1.0 to 0-65535 (16-bit integer range)
    u_int := u32(clamp(u, 0, 1) * 65535.0);
    v_int := u32(clamp(v, 0, 1) * 65535.0);

    // Shift v to the top 16 bits, keep u in bottom 16 bits
    packed := (v_int << 16) | u_int;

    // Reinterpret bits as float to store in vertex.z
    return transmute(f32)packed;
}

create_glyphs :: proc(
    text:       string,
    entity_id:  i32,
    font:       ^types.Font,
    x_start:    f32,
    y_start:    f32,
    allocator:  mem.Allocator = context.allocator) -> [dynamic]types.Vertex {
    vertices := make([dynamic]types.Vertex, allocator = allocator);

    x := x_start;
    y := y_start;

    first_char := true;

    for r in text {
        if r < 32 || r > 126 do continue;

        q: ttf.aligned_quad;
        ttf.GetBakedQuad(raw_data(font.cdata[:]), 512, 512, i32(r) - 32, &x, &y, &q, b32(1));

        // Strip Order: BL -> BR -> TL -> TR
        v_bl := types.Vertex{ entity_id = entity_id, position = { q.x0, q.y0, pack_uv(q.s0, q.t0)} };
        v_br := types.Vertex{ entity_id = entity_id, position = { q.x1, q.y0, pack_uv(q.s1, q.t0)} };
        v_tl := types.Vertex{ entity_id = entity_id, position = { q.x0, q.y1, pack_uv(q.s0, q.t1)} };
        v_tr := types.Vertex{ entity_id = entity_id, position = { q.x1, q.y1, pack_uv(q.s1, q.t1)} };

        if !first_char {
        // Repeat the LAST vertex of the previous quad
            append(&vertices, vertices[len(vertices)-1]);

            // Repeat the FIRST vertex of the current quad
            append(&vertices, v_bl);
        }

        append(&vertices, v_bl);
        append(&vertices, v_br);
        append(&vertices, v_tl);
        append(&vertices, v_tr);

        first_char = false;
    }

    return vertices;
}

// TODO: Use stb-image to load the image into memory.
load_image :: proc (filepath: string = "./res/images/triangle_hello_world.jpg") {

}



