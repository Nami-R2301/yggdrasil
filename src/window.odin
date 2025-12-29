package ygg;

import fmt      "core:fmt";
import strings  "core:strings";
import runtime  "base:runtime";

import glfw     "vendor:glfw";

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
create_window :: proc "c" (
    title:          string,
    profile:        string = "debug",
    dimensions:     types.Dimension = { 800, 600 },
    offset:         types.Dimension = { 0, 0 },
    gl_version:     [2]i32 = {3, 3},
    refresh_rate:   types.Option(u16) = nil,
    indent:         string = "  ") -> types.Window {
    using types;
    using utils;

    context = runtime.default_context();
    assert(bool(glfw.Init()), "[ERR]:\tFATAL: Cannot initialize GLFW");

    major, minor, _ := glfw.GetVersion();
    fmt.printf("[INFO]:{}| Creating window '{}' (GLFW {}.{}) ... ", indent, title, major, minor);
    glfw.SetErrorCallback(glfw_error_callback);
    new_window : Window = { };

    glfw.WindowHint(glfw.OPENGL_DEBUG_CONTEXT, profile == "debug");
    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, gl_version[0]);
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, gl_version[1]);
    glfw.WindowHint(glfw.OPENGL_FORWARD_COMPAT, true);
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE);
    glfw.WindowHint(glfw.MAXIMIZED, true);
    glfw.WindowHint(glfw.REFRESH_RATE, is_some(refresh_rate) ? i32(unwrap(refresh_rate)) : glfw.DONT_CARE);

    window_dimensions := dimensions;
    glfw_handle := glfw.CreateWindow(i32(window_dimensions[0]), i32(window_dimensions[1]),
    strings.unsafe_string_to_cstring(title), nil, nil);

    glfw.MakeContextCurrent(glfw_handle);
    glfw.SetFramebufferSizeCallback(glfw_handle, glfw_framebuffer_callback);
    glfw.SwapInterval(1);

    new_window.glfw_handle = glfw_handle;
    new_window.title = title;
    new_window.dimensions = dimensions;
    new_window.offset = offset;
    new_window.refresh_rate = refresh_rate;
    new_window.gl_version = gl_version;

    fmt.println("Done");
    return new_window;
}

destroy_window :: proc "c" (window_handle: ^types.Window, indent: string = "  ") -> types.WindowError {
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

is_window_running :: proc "c" (window_ptr: ^types.Window) -> bool {
    if window_ptr == nil || window_ptr.glfw_handle == nil {
        return false;
    }

    return !bool(glfw.WindowShouldClose(window_ptr.glfw_handle));
}

poll_events :: proc "c" (window_ptr: ^types.Window) {
    if window_ptr == nil || window_ptr.glfw_handle == nil {
        return;
    }

    glfw.PollEvents();
}

swap_buffers :: proc "c" (window_ptr: ^types.Window) {
    if window_ptr == nil || window_ptr.glfw_handle == nil {
        return;
    }

    glfw.SwapBuffers(window_ptr.glfw_handle);
}

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