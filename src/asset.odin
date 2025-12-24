package ygg;

import fmt      "core:fmt";
import os       "core:os";
import strings  "core:strings";
import runtime  "base:runtime";
import ttf      "vendor:stb/truetype";
import gl       "vendor:OpenGL";

import types "types";

init_font :: proc (font_name: string = "./res/fonts/default/JetBrainsMono-Regular.ttf", indent: string = "  ") -> types.Error {
    using types;

    assert(context.user_ptr != nil, "[ERR]:\tCannot init font: Context is nil");
    ctx := cast(^Context)context.user_ptr;

    new_indent := strings.concatenate({indent, "  "});
    defer delete(new_indent);

    font, font_err := load_font(font_name, new_indent);
    if font_err != FontError.None {
        fmt.eprintfln("[ERR]:{} --- Cannot init font {}: {}", indent, font_name, font_err);
        return font_err;
    }

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
    return FontError.None;
}

load_font :: proc (path: string, indent: string = "  ") -> (font: types.Font, err: types.Error) {
    using types;

    fmt.printfln("[INFO]:{}| Loading font file {} ... ", indent, path);
    bytes := os.read_entire_file_from_filename_or_err(path) or_return;
    font_info, alloc_err := new(ttf.fontinfo);
    if alloc_err != runtime.Allocator_Error.None {
        fmt.eprintfln("[ERR]:{} --- Cannot add font {}: Alloc error: {}", indent, path, alloc_err);
        return { }, alloc_err;
    }
    defer free(font_info);

    if !ttf.InitFont(font_info, raw_data(bytes), 0) {
        return { }, FontError.InvalidFont;
    }

    font = Font{
        width_pixels = 16,
        height_pixels = 16,
        bytes = bytes,
        font_bitmap = make([]u8, 512 * 512),
        cdata = make([]ttf.bakedchar, 96)
    };

    fmt.printfln("[INFO]:{}--- Done", indent);
    return font, FontError.None;
}

// TODO: Use stb-image to load the image into memory.
load_image :: proc (filepath: string = "./res/images/triangle_hello_world.jpg") {

}



