package types;

Buffer :: struct {
    id: u32,
    type: BufferType,
    size: u64,
    count: u64,
    capacity: u64
}

BufferError :: enum u8 {
    None = 0,
    InvalidPtr,
    BufferNotFound,
    InvalidSize,
    ExceededMaxSize,
}

BufferType :: enum u8 {
    vbo = 0,
    vao,
    ibo,
    ubo,
    framebuffer,
    texture
}

