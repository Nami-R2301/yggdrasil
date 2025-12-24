package retained;

import fmt      "core:fmt";
import strings  "core:strings";
import vmem     "core:mem/virtual";
import mem      "core:mem";

import core "../";
import types "../types";
import utils "../utils"

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
    indent:             string = "  ") -> (ctx: types.Context, err: types.Error) {
    using types;
    using utils;

    ctx = Context {
        window                  = window_handle,
        root                    = nil,
        last_node               = nil,
        cursor                  = { 0, 0 },
        renderer                = renderer_handle,
        config                  = config,
        _arena                  = new(vmem.Arena)
    };

    // This library does not free its individual dynamic allocs. Just put the whole context in an arena and no leaking
    // will happen as long as you destroy it.
    if err = vmem.arena_init_growing(ctx._arena, 1 * mem.Gigabyte); err != vmem.Allocator_Error.None {
        fmt.eprintfln("[ERR]:{} --- Cannot create context: Arena alloc error: {}", indent, err);
        free(ctx._arena);
        return {}, ContextError.ArenaAllocFailed;
    }
    ctx.allocator = vmem.arena_allocator(ctx._arena);

    level : LogLevel = into_debug(config["log_level"]);

    if level != LogLevel.None {
        fmt.printfln("[INFO]:{}| Creating context...", indent);
    }

    if level != LogLevel.None {
        str := into_str(&ctx, "           ");
        fmt.printfln("[INFO]:{0}--- Done (\n{2} {1}\n         )", indent, str, "          ");
    }

    return ctx, ContextError.None;
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
    ctx.config = {};

    if level >= LogLevel.Normal {
        str := into_str(ctx, "    ");
        fmt.printfln("[INFO]:{}--- Done (%p) :\n{}", indent, ctx, str);
    }
}

// Retained API to destroy manually a context, Useful for fine-grain control over the context's
// lifetime.
//
// @param   *ctx*:      The context in question.
// @param   *indent*:   The depth of the indent for all logs within this function.
// @return  If there were any errors destroying the context.
destroy_context :: proc (indent: string = "  ") -> types.Error {
    using types;
    using utils;

    if context.user_ptr == nil {
        return ContextError.InvalidContext;
    }

    ctx: ^Context = cast(^Context)context.user_ptr;
    level : LogLevel = into_debug(ctx.config["log_level"]);

    if level >= LogLevel.Normal {
        fmt.printfln("[INFO]:{}| Destroying context (%p) ...", indent, ctx);
    }

    if ctx.root != nil {
        new_indent , _ := strings.concatenate({ indent, "  " }, context.temp_allocator);
        destroy_node(ctx.root.id, indent = new_indent);
    }

    if ctx.renderer != nil {
        new_indent := strings.concatenate({indent, "  "}, context.temp_allocator);
        core.destroy_renderer(ctx.renderer, new_indent);
    }

    if ctx.window != nil {
        new_indent := strings.concatenate({indent, "  "}, context.temp_allocator);
        core.destroy_window(ctx.window, new_indent);
    }

    if level >= LogLevel.Normal {
        fmt.printfln("[INFO]:{}--- Done", indent);
    }

    free_all(ctx.allocator);
    vmem.arena_destroy(ctx._arena);
    free(ctx._arena);
    return ContextError.None;
}