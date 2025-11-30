package types;

Buffer :: struct {
    attachments_opt: []u32,
    size: u64,
    count: u64,
    capacity: u64,
    length: u64,
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
    Ibo,
    Ubo,
    Framebuffer,
}

