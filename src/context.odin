package ygg;

import fmt      "core:fmt";
import strings  "core:strings";
import vmem     "core:mem/virtual";
import mem      "core:mem";
import runtime  "base:runtime";

import types "types";
import utils "utils"

// Core API to construct a new context. This is intended to be used by both retained and immediate APIs. Note that,
// the context is different from the 'context' global variable used by odin-lang. Speaking of, you HAVE to set odin's
// context to the ygg context you create like so: 'context.user_ptr = &ctx' in order to call API functions that depend
// on a context (almost all of them in core, all in immediate and retained APIs).
//
// @lifetime                    An arena gets initialized for the whole context. The actual context object
//                              does not get allocated on the heap, but it is imperative to call 'destroy_context(...)'
//                              if you want to deallocate all data correctly if your app does not exit immediately.
//
// @param   *window_handle*:    A pointer to a valid window struct which will determine the window framebuffer
//                              onto which the nodes will render to. If nil, a new one will be created in its place.
// @param   *renderer_handle*:  A handle to the renderer that will take care of batching and process
//                              nodes in the render queue. If nil, a new one will be created in its place.
// @param   *config*:           A key-value pair containing the options and features to toggle on/off.
// @param   *indent*:           The depth of the indent for all logs within this function.
//
// @return                      If there was an error creating the context and a new context depending on if it succeeded.
create_context :: proc "c" (
    window_handle:      ^types.Window   = nil,
    renderer_handle:    ^types.Renderer = nil,
    config:             map[string]string = {},
    indent:             string = "  ") -> (ctx: types.Context, err: types.Error) {
    using types;

    context = runtime.default_context();

    ctx = Context {
        window                  = window_handle,
        root                    = nil,
        last_node               = nil,
        config                  = config,
        cursor                  = { 0, 0 },
        renderer                = renderer_handle,
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
    new_indent := strings.concatenate({indent, "  "}, context.temp_allocator);

    if len(ctx.config) == 0 {
        sanitized_config, error := sanitize_config(indent = new_indent, allocator = ctx.allocator);
        if error != ConfigError.None {
            fmt.eprintfln("[ERR]:  --- Error creating context: {}", error);
            return {}, error
        }
        ctx.config = sanitized_config;
    }

    level : LogLevel = utils.into_debug(ctx.config["log_level"]);
    if level != LogLevel.None {
        fmt.printfln("[INFO]:{}| Creating context ... ", indent);
    }

    if ctx.window == nil && !utils.into_bool(ctx.config["headless"]) {
        window := create_window("Yggdrasil (Debug)", indent = new_indent);
        ctx.window = new_clone(window, ctx.allocator);
    }

    if ctx.window != nil && ctx.renderer == nil {
        if level >= LogLevel.Verbose {
            fmt.printfln("[WARN]:  --- No renderer handle found, creating one ...");
        }
        renderer := create_renderer(ctx.window, indent = new_indent);
        ctx.renderer = new_clone(renderer, ctx.allocator);

        // Setup default font glyphs for text rendering
        init_font(&ctx, indent = new_indent);
    }

    if level >= LogLevel.Verbose {
        str := utils.into_str(&ctx, "           ");
        fmt.printfln("[INFO]:{0}--- Done (\n{2} {1}\n         )", indent, str, "          ");
    } else {
        fmt.printfln("[INFO]:{}--- Done", indent);
    }

    return ctx, ContextError.None;
}

// Core API to completely reset the context tree, in the event you are conditionally resetting
// a context to re-use it later in your procedure pipeline.
//
// @lifetime            Static, no heap allocation - you may freely call this anywhere without worrying
//                      about memory footprint.
//
// @param   *ctx*:      Context to reset.
// @param   *indent*:   The depth of the indent for all logs within this function.
//
// @return              Nothing, since we are only changing the context in place.
reset_context :: proc "c" (ctx: runtime.Context, indent: string = "  ") {
    using types;

    assert_contextless(ctx.user_ptr != nil, "[ERR]:\t| Error resetting context: Context is nil!");

    context = ctx;
    ygg_ctx: ^Context = cast(^Context)ctx.user_ptr;

    level : LogLevel = utils.into_debug(ygg_ctx.config["log_level"]);
    if level >= LogLevel.Normal {
        str := utils.into_str(ygg_ctx);
        fmt.printfln("[INFO]:{}| Resetting context (%p) ... :\n{}", indent, ygg_ctx, str);
    }

    ygg_ctx.config["log_level"] = "";
    ygg_ctx.root = nil;
    ygg_ctx.window = nil;
    ygg_ctx.cursor = { 0, 0 };
    ygg_ctx.last_node = nil;
    ygg_ctx.config = {};

    // Init offset and zero memory
    vmem.arena_destroy(ygg_ctx._arena);

    if level >= LogLevel.Normal {
        str := utils.into_str(ygg_ctx, "    ");
        fmt.printfln("[INFO]:{}--- Done (%p) :\n{}", indent, ygg_ctx, str);
    }
}

// Core API to destroy a context. When destroying a context, all memory allocated within it gets destroyed. So
// once destroyed, the context is unusable. If you need to only reset the context, check out 'reset_context(...)'.
// You MUST call this if you want to properly clean heap memory used within this context, unless your app immediately
// exists after use.
//
// @lifetime            The context's arena gets destroyed along with all of its data. Must be called ONCE per context.
//                      Does not require context's 'user_ptr' to be set.
//
// @param   *ctx*:      The context in question.
// @param   *indent*:   The depth of the indent for all logs within this function.
//
// @return              Nothing. This function does not handle memory allocation errors like other functions, since it
//                      terminates and frees the arena holding that memory anyway.
destroy_context :: proc "c" (ctx: runtime.Context, indent: string = "  ") {
    using types;

    assert_contextless(ctx.user_ptr != nil, "[ERR]:\tCannot destroy context: Ygg Context is nil. Did you forget to call " +
    "'create_context(...)' ?");

    context = ctx;
    ygg_ctx: ^Context = cast(^Context)ctx.user_ptr;

    level : LogLevel = utils.into_debug(ygg_ctx.config["log_level"]);

    if level >= LogLevel.Normal {
        fmt.printfln("[INFO]:{}| Destroying context (%p) ...", indent, ygg_ctx);
    }

    if ygg_ctx.root != nil {
        new_indent , _ := strings.concatenate({ indent, "  " }, context.temp_allocator);
        destroy_node(ctx, ygg_ctx.root.id, indent = new_indent);
    }

    if ygg_ctx.renderer != nil {
        new_indent := strings.concatenate({indent, "  "});
        destroy_renderer(ygg_ctx.renderer, new_indent);
    }

    if ygg_ctx.window != nil {
        new_indent := strings.concatenate({indent, "  "}, context.temp_allocator);
        destroy_window(ygg_ctx.window, new_indent);
    }

    if level >= LogLevel.Normal {
        fmt.printfln("[INFO]:{}--- Done", indent);
    }

    vmem.arena_destroy(ygg_ctx._arena);
    free(ygg_ctx._arena);
}