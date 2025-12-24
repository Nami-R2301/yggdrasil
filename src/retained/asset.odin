package retained;

import ttf   "vendor:stb/truetype";
import mem   "core:mem";

import types "../types";

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
    using types;

    vertices := make([dynamic]Vertex, allocator = allocator);

    x := x_start;
    y := y_start;

    first_char := true;

    for r in text {
        if r < 32 || r > 126 do continue;

        q: ttf.aligned_quad;
        ttf.GetBakedQuad(raw_data(font.cdata[:]), 512, 512, i32(r) - 32, &x, &y, &q, b32(1));

        // Strip Order: BL -> BR -> TL -> TR
        v_bl := Vertex{ entity_id = entity_id, position = { q.x0, q.y0, pack_uv(q.s0, q.t0)} };
        v_br := Vertex{ entity_id = entity_id, position = { q.x1, q.y0, pack_uv(q.s1, q.t0)} };
        v_tl := Vertex{ entity_id = entity_id, position = { q.x0, q.y1, pack_uv(q.s0, q.t1)} };
        v_tr := Vertex{ entity_id = entity_id, position = { q.x1, q.y1, pack_uv(q.s1, q.t1)} };

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