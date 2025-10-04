package ygg;

import "core:fmt";
import "core:strings";
import "vendor:glfw";

import types "types";
import utils "utils";

////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////// LOW LEVEL API //////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////


// Low-level API to create a window context with either OpenGL or Vulkan as the GPU API.
//
// @param   *title*:          The window's title.
// @param   *profile*:        Whether to optimize OpenGL's context or not. Defaults to debug mode.
// @param   *target*:         Whether to use OpenGL or Vulkan. Defaults to OpenGL.
// @param   *dimensions*:     How big the window should be.
// @param   *offset*:         Where on the screen should the window pop up.
// @param   *refresh_rate*:   How many frames the context should output, utils.none() will default to vsync.
// @return  If an error occurred or not and the window if it has been created without errors.
_create_window :: proc (
    title:          string,
    profile:        string = "debug",
    target:         types.RendererType = types.RendererType.OpenGL,
    dimensions:     types.Option([2]u16) = nil,
    offset:         types.Option([2]u16) = nil,
    refresh_rate:   types.Option(u16) = nil,
    indent:         string = "  ") -> types.Result(types.Window) {
    using types;
    using utils;

    if !bool(glfw.Init()) {
        fmt.printfln("[ERR]:{}--- FATAL: Cannot initialize GLFW", indent);
        return { error = WindowError.InitError, opt = none(types.Window) };
    }
    new_window : Window = { };

    window_dimensions := unwrap_or(dimensions, [2]u16{ 800, 600 });
    glfw_handle := glfw.CreateWindow(i32(window_dimensions[0]), i32(window_dimensions[1]),
    strings.unsafe_string_to_cstring(title), nil, nil);

    if target == RendererType.OpenGL {
        glfw.WindowHint_bool(glfw.OPENGL_DEBUG_CONTEXT, profile == "debug");
        glfw.WindowHint(glfw.CLIENT_API, glfw.OPENGL_API);
        glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE);
    } else {
    // Vulkan
        glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API);
    }
    glfw.WindowHint(glfw.VERSION_MAJOR, 3);
    glfw.WindowHint(glfw.VERSION_MINOR, 3);

    glfw.WindowHint(glfw.REFRESH_RATE, is_some(refresh_rate) ? i32(unwrap(refresh_rate)) : -1);

    glfw.SwapInterval(1);
    glfw.MakeContextCurrent(glfw_handle);

    new_window.glfw_handle = glfw_handle;
    new_window.title = title;
    new_window.dimensions = unwrap_or(dimensions, [2]u16{ 800, 600 });
    new_window.offset = unwrap_or(offset, [2]u16{ 0, 0 });
    new_window.refresh_rate = refresh_rate;

    return { error = WindowError.None, opt = utils.some(new_window) };
}

// TODO: Graceful window shutdown process.
_destroy_window :: proc (window_handle: ^types.Window, indent: string = "  ") -> types.WindowError {
    panic("Unimplemented");
}