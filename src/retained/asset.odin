package retained;

import ttf   "vendor:stb/truetype";

import types "../types";

create_glyphs :: proc(text: string, font: ^types.Font, x_start: f32, y_start: f32) -> [dynamic]types.Glyph {
    using types;

    vertices := make([dynamic]Glyph);

    // Create a mutable X and Y that 'GetBakedQuad' will update as it moves right
    x := x_start;
    y := y_start;

    for r in text {
        if r < 32 || r > 126 do continue // Skip unsupported chars

        // The magic struct that holds the quad math
        q: ttf.aligned_quad;

        // Calculate the quad for this specific character
        // '1' = OpenGL mode (Y grows upwards)
        ttf.GetBakedQuad(raw_data(font.cdata[:]), 512, 512, i32(r) - 32, &x, &y, &q, b32(1));

        // Push the two triangles (6 vertices) that make the square
        // Triangle 1
        append(&vertices, Glyph{ entity_id = 2, x = q.x0, y = q.y0, z = q.s0, w = q.t0, color = {1, 1, 1, 1} }); // Bottom-Left
        append(&vertices, Glyph{ entity_id = 2, x = q.x1, y = q.y0, z = q.s1, w = q.t0, color = {1, 1, 1, 1} }); // Bottom-Right
        append(&vertices, Glyph{ entity_id = 2, x = q.x1, y = q.y1, z = q.s1, w = q.t1, color = {1, 1, 1, 1} }); // Top-Right

        // Triangle 2
        append(&vertices, Glyph{ entity_id = 2, x = q.x0, y = q.y0, z = q.s0, w = q.t0, color = {1, 1, 1, 1} }); // Bottom-Left
        append(&vertices, Glyph{ entity_id = 2, x = q.x1, y = q.y1, z = q.s1, w = q.t1, color = {1, 1, 1, 1} }); // Top-Right
        append(&vertices, Glyph{ entity_id = 2, x = q.x0, y = q.y1, z = q.s0, w = q.t1, color = {1, 1, 1, 1} }); // Top-Left
    }

    return vertices;
}