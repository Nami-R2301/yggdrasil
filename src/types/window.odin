package types;

import "vendor:glfw";

Window :: struct {
    glfw_handle: glfw.WindowHandle,
    title: string,
    dimensions: [2]u16,
    refresh_rate: Option(u16),
    offset: [2]u16
}

WindowError :: enum u8 {
    None = 0,
    InitError,
    InvalidWindow
}