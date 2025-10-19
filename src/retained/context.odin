package retained;

import glfw "vendor:glfw";
import fmt "core:fmt";
import strings "core:strings";

import core "../";
import types "../types";
import utils "../utils";

////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////// RETAINED API ///////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Retained API to construct a new context. This is intended to be used by the immediate API, but
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
create_context :: proc (
    window_handle:      ^types.Window   = nil,
    renderer_handle:    ^types.Renderer = nil,
    config:             map[string]string,
    indent:             string = "  ") -> types.Result(types.Context) {
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

    return { error = ContextError.None, opt = some(ctx) };
}

// Retained API to completely reset the context tree, in the event you are conditionally resetting
// a context to re-use it later in your procedure pipeline.
//
// @lifetime            Static, no heap allocation - you may freely call this anywhere without worrying
//                      about memory footprint.
// @param   *ctx*:      Context to reset.
// @param   *indent*:   The depth of the indent for all logs within this function.
// @return  Nothing, since we are only changing the context in place.
reset_context :: proc (ctx: ^types.Context, indent: string = "  ") {
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

// Retained API to destroy manually a context, Useful for fine-grain control over the context's
// lifetime.
//
// @param   *ctx*:      The context in question.
// @param   *indent*:   The depth of the indent for all logs within this function.
// @return  If there were any errors destroying the context.
destroy_context :: proc (ctx: ^types.Context, indent: string = "  ") -> types.Error {
    using types;
    using utils;

    assert(ctx != nil, "[ERR]:\t| Error resetting context: Context is nil!");

    if len(ctx.config) > 0 {
        delete_map(ctx.config);
    }

    level : LogLevel = into_debug(ctx.config["log_level"]);

    if level >= LogLevel.Normal {
        fmt.printfln("[INFO]:{}| Destroying context (%p) ...", indent, ctx);
    }

    if ctx.root != nil {
        new_indent , _ := strings.concatenate({ indent, "  " });
        destroy_node(ctx, ctx.root.id, new_indent);
        delete_string(new_indent);
        free(ctx.root);
    }

    if ctx.renderer != nil {
        new_indent := strings.concatenate({indent, "  "});
        core.destroy_renderer(ctx.renderer);
        delete_string(new_indent);
    }

    if ctx.window != nil {
        new_indent := strings.concatenate({indent, "  "});
        core.destroy_window(ctx.window, new_indent);
        delete_string(new_indent);
    }

    if level >= LogLevel.Normal {
        fmt.printfln("[INFO]:{}--- Done", indent);
    }

    return ContextError.None;
}