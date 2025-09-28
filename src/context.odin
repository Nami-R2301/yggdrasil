package yggdrasil;

import "vendor:glfw";
import "core:fmt";
import "core:strings";

import types "types";
import utils "utils";

////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////// HIGH LEVEL API /////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////

// High-level API to create and setup a new context to attach/render nodes into. Note, that this function
// unlike its low-level counterpart, does not accept a config. Instead, the config is implicitely read
// from the config.toml file. This file needs to live alongside the executable's directory to be read
// properly. This procedure will create a default window and renderer if headless mode is not specified
// in the config file.
//
// @lifetime    Explicit - You will need to call terminate_context if you wish to correctly free up
//              resources and clear the context tree. Will leak memory if not terminated, albeit
//              a very small amount of bytes.
// @param       *window_handle*:    A window ptr containing an valid window structure, indicating the
//                                  framebuffer that will be used to display UI elements.
// @param       *renderer_handle*:  A pointer referring to a renderer that will be used to render nodes.
// @return      An error if one occurred and if the context has been setup successfully.
init_context :: proc (
    window_handle:   ^types.Window   = nil,
    renderer_handle: ^types.Renderer = nil) -> (types.Error, types.Option(types.Context)) {
    using types;
    using utils;

    parse_error, parsed_config_opt := _sanitize_config();
    if parse_error != ConfigError.None {
        fmt.eprintfln("[ERR]:  --- Error creating context: {}", parse_error);
        return parse_error, none(Context);
    }
    parsed_config := unwrap(parsed_config_opt);

    level : LogLevel = into_debug(parsed_config["log_level"]);

    new_window := window_handle;
    new_renderer := renderer_handle;

    if level >= LogLevel.Verbose {
        fmt.printfln("[INFO]:{}  --- Config initialized: {}", "  ", parsed_config);
    }

    if new_window == nil && !into_bool(parsed_config["headless"]) {
        window_error, window_opt := _create_window("Yggdrasil (Debug)");
        if window_error != WindowError.None {
            return window_error, none(Context);
        }

        new_window = new_clone(unwrap(window_opt));
    }

    if new_renderer == nil && into_bool(parsed_config["renderer"]) {
        if level >= LogLevel.Verbose {
            fmt.printfln("[WARN]:  --- No renderer handle found, creating one ...");
        }
        renderer_error, renderer_opt := _create_renderer(type = RendererType.OpenGL, bg_color = 0x181818);
        if renderer_error != RendererError.None {
            return RendererError.InitError, none(Context);
        }

        new_renderer = new_clone(unwrap(renderer_opt));
    }
    return _create_context(window_handle, renderer_handle, config = parsed_config);
}

// High-level API to delete and free up context provided. This is necessary to call to free up resources
// correctly to avoid memory leaking. Note, that if you only have one context that only gets terminated
// at the end of your application's lifetime, you may omit this call if you do not care for a graceful
// shutdown process.
//
// @lifetime        Static - no additional heap allocations - you may freely call this anywhere without worrying
//                  about memory footprint as long as the context is valid.
// @param   *ctx*: Context to free and terminate.
// @return  An error if one occurred.
terminate_context :: proc (ctx: ^types.Context) -> types.Error {
    error := _destroy_context(ctx);
    delete_map(ctx.config);

    if ctx.window != nil {
        free(ctx.window);
    }

    if ctx.renderer != nil {
        free(ctx.renderer);
    }

    return error;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////// LOW LEVEL API //////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Low-level API to construct a new context. This is intended to be used by the high-level APIs, but
// can prove useful for cases where you would need to explicitely control the lifetime of the context.
//
// @lifetime                    Static, no heap allocation - you may freely call this anywhere without worrying
//                              about memory footprint.
// @param   *window_handle*:    A pointer to a valid window struct which will determine the window framebuffer
//                              onto which the nodes will render to.
// @param   *renderer_handle*:  A handle to the renderer that will take care of batching and process
//                              nodes in the render queue.
// @param   *config*:           A key-value pair containing the options and features to toggle on/off.
// @param   *indent*:           The depth of the indent for all logs within this function.
// @return  If there was an error creating the context and a new context depending on if it succeeded.
_create_context :: proc (
    window_handle:      ^types.Window   = nil,
    renderer_handle:    ^types.Renderer = nil,
    config:             map[string]string,
    indent:             string = "  ") -> (types.Error, types.Option(types.Context)) {
    using types;
    using utils;

    level : LogLevel = into_debug(config["log_level"]);

    if level != LogLevel.None {
        fmt.printfln("[INFO]:{}| Creating context...", indent);
    }

    ctx := Context {
        window                  = window_handle,
        root                    = nil,
        last_node               = nil,
        cursor                  = { 0, 0 },
        renderer                = renderer_handle,
        config                  = config,
        nodes_created           = 0,
        keyboardEventHandlers   = {},
        mouseEventHandlers      = {},
    };

    if level != LogLevel.None {
        str := into_str(&ctx, "           ");
        fmt.printfln("[INFO]:{0}--- Done (\n{2} {1}\n         )", indent, str, "          ");
        delete_string(str);
    }

    return ContextError.None, some(ctx);
}

// Low-level API to completely reset the context tree, in the event you are conditionally resetting
// a context to re-use it later in your procedure pipeline.
//
// @lifetime            Static, no heap allocation - you may freely call this anywhere without worrying
//                      about memory footprint.
// @param   *ctx*:      Context to reset.
// @param   *indent*:   The depth of the indent for all logs within this function.
// @return  Nothing, since we are only changing the context in place.
_reset_context :: proc (ctx: ^types.Context, indent: string = "  ") {
    using types;
    using utils;

    assert(ctx != nil, "[ERR]:\t| Error resetting context: Context is nil!");

    level : LogLevel = into_debug(ctx.config["log_level"]);
    if level >= LogLevel.Normal {
        str := into_str(ctx);
        fmt.printfln("[INFO]:{}| Resetting context (%p) ... :\n{}", indent, ctx, str);
        delete_string(str);
    }

    ctx.config["log_level"] = "";
    ctx.root = nil;
    ctx.window = nil;
    ctx.cursor = { 0, 0 };
    ctx.last_node = nil;
    ctx.nodes_created = 0;
    ctx.keyboardEventHandlers = {};
    ctx.mouseEventHandlers = {};

    delete_map(ctx.config);
    ctx.config = {};

    if level >= LogLevel.Normal {
        str := into_str(ctx, "    ");
        fmt.printfln("[INFO]:{}--- Done (%p) :\n{}", indent, ctx, str);
        delete_string(str);
    }
}

// Low-level API to destroy manually a context, Useful for fine-grain control over the context's
// lifetime.
//
// @param   *ctx*:      The context in question.
// @param   *indent*:   The depth of the indent for all logs within this function.
// @return  If there were any errors destroying the context.
_destroy_context :: proc (ctx: ^types.Context, indent: string = "  ") -> types.ContextError {
    using types;
    using utils;

    assert(ctx != nil, "[ERR]:\t| Error resetting context: Context is nil!");

    level : LogLevel = into_debug(ctx.config["log_level"]);

    if level >= LogLevel.Normal {
        fmt.printfln("[INFO]:{}| Destroying context (%p) ...", indent, ctx);
    }

    if ctx.root != nil {
        new_indent , _ := strings.concatenate({ indent, "  " });
        _ = _destroy_node(ctx, ctx.root.id, new_indent);
        delete_string(new_indent);
        free(ctx.root);
    }

    if ctx.renderer != nil {
        _ = _destroy_renderer(ctx.renderer);
    }

    if level >= LogLevel.Verbose {
        fmt.printf("[INFO]:{}  | Destroying window (%p)...", indent, ctx.window);
    }

    if ctx.window != nil {
        glfw.DestroyWindow(ctx.window.glfw_handle);
    }

    if level >= LogLevel.Normal {
        fmt.println(" Done");
        fmt.printfln("[INFO]:{}--- Done", indent);
    }

    return ContextError.None;
}
