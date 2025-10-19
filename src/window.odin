package ygg;

import fmt "core:fmt";
import strings "core:strings";
import glfw "vendor:glfw";
import libc "core:c/libc";

import types "types";
import utils "utils";

////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////// CORE //////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////


// Core API to create a window context with either OpenGL or Vulkan as the GPU API.
//
// @param   *title*:          The window's title.
// @param   *profile*:        Whether to optimize OpenGL's context or not. Defaults to debug mode.
// @param   *target*:         Whether to use OpenGL or Vulkan. Defaults to OpenGL.
// @param   *dimensions*:     How big the window should be.
// @param   *offset*:         Where on the screen should the window pop up.
// @param   *refresh_rate*:   How many frames the context should output, utils.none() will default to vsync.
// @return  If an error occurred or not and the window if it has been created without errors.
create_window :: proc (
    title:          string,
    profile:        string = "debug",
    target:         types.RendererType = types.RendererType.OpenGL,
    dimensions:     [2]u16 = { 800, 600 },
    offset:         [2]u16 = { 0, 0 },
    refresh_rate:   types.Option(u16) = nil,
    indent:         string = "  ") -> types.Result(types.Window) {
    using types;
    using utils;

    fmt.printfln("[INFO]:{}| Creating window '{}' ... ", indent, title);
    if !bool(glfw.Init()) {
        fmt.eprintfln("[ERR]:{}--- FATAL: Cannot initialize GLFW", indent);
        return { error = WindowError.InitError, opt = none(types.Window) };
    }
    new_window : Window = { };

    window_dimensions := dimensions;
    glfw_handle := glfw.CreateWindow(i32(window_dimensions[0]), i32(window_dimensions[1]),
    strings.unsafe_string_to_cstring(title), nil, nil);

    major, minor, _ := glfw.GetVersion();
    fmt.printfln("[INFO]:{}  --- GLFW version: {}.{}", indent, major, minor);

    if target == RendererType.OpenGL {
        glfw.WindowHint_bool(glfw.OPENGL_DEBUG_CONTEXT, profile == "debug");
        glfw.WindowHint(glfw.CLIENT_API, glfw.OPENGL_API);
        glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE);
    } else {
        // Vulkan
        glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API);
    }
    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3);
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3);
    glfw.WindowHint(glfw.FLOATING, true);

    glfw.WindowHint(glfw.REFRESH_RATE, is_some(refresh_rate) ? i32(unwrap(refresh_rate)) : glfw.DONT_CARE);

    glfw.SwapInterval(1);
    glfw.MakeContextCurrent(glfw_handle);

    new_window.glfw_handle = glfw_handle;
    new_window.title = title;
    new_window.dimensions = dimensions;
    new_window.offset = offset;
    new_window.refresh_rate = refresh_rate;

    fmt.printfln("[INFO]:{}--- Done", indent);
    return { error = WindowError.None, opt = utils.some(new_window) };
}

destroy_window :: proc (window_handle: ^types.Window, indent: string = "  ") -> types.WindowError {
    fmt.printf("[INFO]:{}| Destroying window '{}' ... ", indent, window_handle.title);
    if window_handle == nil {
        fmt.eprintfln("\n[ERR]:{}--- Error destroying window: Window nil!");
        return types.WindowError.InvalidWindow;
    }

    glfw.DestroyWindow(window_handle.glfw_handle);

    fmt.println("Done");
    return types.WindowError.None;
}

is_window_running :: proc (ctx: ^types.Context) -> bool {
    if ctx == nil || ctx.window == nil || ctx.window.glfw_handle == nil || utils.into_bool(ctx.config["headless"]) {
        return false;
    }

    return !bool(glfw.WindowShouldClose(ctx.window.glfw_handle));
}

@(private)
glfw_error_callback :: proc "c" (error_code: int, description: cstring) {
    libc.fprintf(libc.stderr, "[GLFW] | [%d] -> [%s]", error_code, description);
}