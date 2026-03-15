package types;

import "vendor:glfw";

Window :: struct {
    glfw_handle:        glfw.WindowHandle,
    title:              cstring,
    width, height:      u32,
    offset:             [2]Dimension,
    gl_version:         [2]u8,
    refresh_rate_opt:   u16,
}

WindowError :: enum u8 {
    None = 0,
    InitError,
    InvalidWindow
}