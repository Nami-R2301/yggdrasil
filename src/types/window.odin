package types;

import "vendor:glfw";

Window :: struct {
    glfw_handle: glfw.WindowHandle,
    title: string,
    dimensions: Dimension,
    refresh_rate: Option(u16),
    offset: Dimension
}

WindowError :: enum u8 {
    None = 0,
    InitError,
    InvalidWindow
}