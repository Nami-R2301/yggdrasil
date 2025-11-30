package types;

Buffer :: struct {
    attachments_opt: []u32,
    count: u64,
    length: u64,
    capacity: u64,
    id: u32,
    type: BufferType
}

BufferError :: enum u8 {
    None = 0,
    InvalidPtr,
    BufferNotFound,
    InvalidSize,
    ExceededMaxSize,
    InvalidAttachments  // Something went wrong when setting up texture-based attachments for framebuffer
}

BufferType :: enum u8 {
    Vbo = 0,
    Vao,
    Framebuffer,
}

Vertex :: struct #packed {
    entity_id:  i32,
    position:   [3]f32,  // x, y, z
    color:      [4]f32,
    tex_coords: [2]f32
}

Data :: struct #packed {
    ptr: rawptr,
    count: u64,
    size: u64
}

