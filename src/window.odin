package ygg;

import fmt      "core:fmt";
import runtime  "base:runtime";

import glfw "vendor:glfw";

import types "types";
import utils "utils"

// Core API to create a window context with either OpenGL or Vulkan as the GPU API.
//
// @param   *title*:          The window's title.
// @param   *profile*:        Whether to optimize OpenGL's context or not. Defaults to debug mode.
// @param   *target*:         Whether to use OpenGL or Vulkan. Defaults to OpenGL.
// @param   *dimensions*:     How big the window should be.
// @param   *offset*:         Where on the screen should the window pop up.
// @param   *refresh_rate*:   How many frames the context should output, utils.none() will default to vsync.
// @return  If an error occurred or not and the window if it has been created without errors.
@(export, link_prefix="ygg_", require_results)
create_window :: proc "c" (
    title:              cstring,
    profile:            cstring = "debug",
    width:              u32 = 800,
    height:             u32 = 600,
    gl_major:           u8 = 4,
    gl_minor:           u8 = 3,
    refresh_rate_opt:   Maybe(i32) = nil,
    indent:             cstring = "  ") -> types.Window {
    context = runtime.default_context();
    assert(bool(glfw.Init()), "[ERR]:\tFATAL: Cannot initialize GLFW");

    odin_str := string(indent);
    major, minor, _ := glfw.GetVersion();
    fmt.printfln("[INFO]:{}| Creating window '{}' (GLFW {}.{}) ... ", odin_str, title, major, minor);
    glfw.SetErrorCallback(glfw_error_callback);
    new_window: types.Window = { };

    fmt.printfln("[INFO]:{}--- OpenGL version requested: {}.{}", odin_str, gl_major, gl_minor);

    glfw.WindowHint(glfw.OPENGL_DEBUG_CONTEXT, profile == "debug");
    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, i32(gl_major));
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, i32(gl_minor));
    glfw.WindowHint(glfw.OPENGL_FORWARD_COMPAT, true);
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE);
    glfw.WindowHint(glfw.MAXIMIZED, true);
    glfw.WindowHint(glfw.REFRESH_RATE, refresh_rate_opt != nil ? utils.unwrap(refresh_rate_opt) : glfw.DONT_CARE);
    glfw_handle := glfw.CreateWindow(i32(width), i32(height), title, nil, nil);

    glfw.MakeContextCurrent(glfw_handle);
    glfw.SetFramebufferSizeCallback(glfw_handle, glfw_framebuffer_callback);
    glfw.SwapInterval(1);

    new_window.glfw_handle = glfw_handle;
    new_window.title = title;
    new_window.width = width;
    new_window.height = height;
    new_window.refresh_rate_opt = refresh_rate_opt != nil ? u16(utils.unwrap(refresh_rate_opt)) : 0;
    new_window.gl_version = {gl_major, gl_minor};

    fmt.printfln("[INFO]:{}--- Done", indent);
    return new_window;
}

@(export, link_prefix="ygg_")
destroy_window :: proc "c" (window_handle: ^types.Window, indent: cstring = "  ") -> types.WindowError {
    context = runtime.default_context();

    fmt.printf("[INFO]:{}| Destroying window '{}' ... ", indent, window_handle.title);
    if window_handle == nil {
        fmt.eprintfln("\n[ERR]:{}--- Error destroying window: Window nil!");
        return types.WindowError.InvalidWindow;
    }

    glfw.DestroyWindow(window_handle.glfw_handle);

    fmt.println("Done");
    return types.WindowError.None;
}

@(export, link_prefix="ygg_", require_results)
is_window_running :: proc "c" (window_ptr: ^types.Window) -> bool {
    assert_contextless(window_ptr != nil, "[ERR]:\tCannot check if window is running: Window is nil. Did you forget to " +
    "call 'create_window(...)' ?");

    if window_ptr.glfw_handle == nil {
        return false;
    }

    return !bool(glfw.WindowShouldClose(window_ptr.glfw_handle));
}

@(export, link_prefix="ygg_")
poll_events :: proc "c" (window_ptr: ^types.Window) {
    assert_contextless(window_ptr != nil, "[ERR]:\tCannot poll events: Window is nil. Did you forget to " +
    "call 'create_window(...)' ?");

    if window_ptr.glfw_handle == nil {
        return;
    }

    glfw.PollEvents();
}

@(export, link_prefix="ygg_")
swap_buffers :: proc "c" (window_ptr: ^types.Window) {
    assert_contextless(window_ptr != nil, "[ERR]:\tCannot swap buffers: Window is nil. Did you forget to " +
    "call 'create_window(...)' ?");

    if window_ptr.glfw_handle == nil {
        return;
    }

    glfw.SwapBuffers(window_ptr.glfw_handle);
}

@(private)
glfw_framebuffer_callback :: proc "c" (window: glfw.WindowHandle, width, height: i32) {
    context = runtime.default_context();
    fmt.printfln("[INFO]:  | [Resize] Window resized to ({}x{})", width, height);

    update_viewport_and_camera(width, height, "    ");
}

@(private)
glfw_error_callback :: proc "c" (error_code: i32, description: cstring) {
    context = runtime.default_context();

    fmt.eprintfln("[ERR]:\t | [Error] [{}] -> {}", error_code, description);
}