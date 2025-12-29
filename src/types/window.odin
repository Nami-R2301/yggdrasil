package types;

import "vendor:glfw";

Window :: struct {
    glfw_handle:    glfw.WindowHandle,
    title:          string,
    dimensions:     Dimension,
    refresh_rate:   Option(u16),
    offset:         Dimension,
    gl_version:     [2]i32
}

WindowError :: enum u8 {
    None = 0,
    InitError,
    InvalidWindow
}