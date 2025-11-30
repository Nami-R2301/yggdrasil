package immediate;

import fmt "core:fmt";

import core "../";
import rt "../retained";
import types "../types";
import utils "../utils";

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
    renderer_handle: ^types.Renderer = nil,
    custom_config:   map[string]string = {}) -> types.Result(types.Context) {
    using types;
    using utils;

    parsed_config := custom_config;
    if len(custom_config) == 0 {
        result_config := core.sanitize_config();
        if result_config.error != ConfigError.None {
            fmt.eprintfln("[ERR]:  --- Error creating context: {}", result_config.error);
            return { error = result_config.error, opt = none(Context) };
        }
        parsed_config := unwrap(result_config.opt);
    }

    level : LogLevel = into_debug(parsed_config["log_level"]);

    new_window   := window_handle;
    new_renderer := renderer_handle;

    if level >= LogLevel.Verbose {
        fmt.printfln("[INFO]:{}  --- Config initialized: {}", "  ", parsed_config);
    }

    if new_window == nil && !into_bool(parsed_config["headless"]) {
        result := core.create_window("Yggdrasil (Debug)");
        if result.error != WindowError.None || !is_some(result.opt) {
            return { error = result.error, opt = none(Context) };
        }

        new_window = new_clone(unwrap(result.opt));
    }

    if new_window != nil && new_renderer == nil && into_bool(parsed_config["renderer"]) {
        if level >= LogLevel.Verbose {
            fmt.printfln("[WARN]:  --- No renderer handle found, creating one ...");
        }
        result_renderer := core.create_renderer();
        if result_renderer.error != RendererError.None {
            return { error = RendererError.InitError, opt = none(Context) };
        }

        new_renderer = new_clone(unwrap(result_renderer.opt));
    }
    return rt.create_context(new_window, new_renderer, config = parsed_config);
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
    error := rt.destroy_context(ctx);

    if ctx.window != nil {
        free(ctx.window);
    }

    if ctx.renderer != nil {
        free(ctx.renderer);
    }

    return error;
}