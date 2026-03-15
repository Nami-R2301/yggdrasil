package ygg;

import fmt      "core:fmt";
import strings  "core:strings";
import vmem     "core:mem/virtual";
import mem      "core:mem";
import runtime  "base:runtime";

import types "types";
import utils "utils";

// Core API to construct a new context. This is intended to be used by both retained and immediate APIs. Note that,
// the context is different from the 'context' global variable used by odin-lang. Speaking of, you HAVE to set odin's
// context to the ygg context you create like so: 'context.user_ptr = &ctx' in order to call API functions that depend
// on a context (almost all of them in core, all in immediate and retained APIs).
//
// @lifetime                    An arena gets initialized for the whole context. The actual context object
//                              does get allocated on the heap for C interopivity, thus it is imperative to call
//                              'destroy_context(...) ' if you want to deallocate all data correctly if your app does
//                              not exit immediately.
//
// @param   *window_handle*:    A pointer to a valid window struct which will determine the window framebuffer
//                              onto which the nodes will render to. If nil, a new one will be created in its place.
// @param   *renderer_handle*:  A handle to the renderer that will take care of batching and process
//                              nodes in the render queue. If nil, a new one will be created in its place.
// @param   *config*:           A key-value pair containing the options and features to toggle on/off.
// @param   *indent*:           The depth of the indent for all logs within this function.
//
// @return                      If there was an error creating the context and a new context depending on if it succeeded.
@(export, link_prefix="ygg_", require_results)
create_context :: proc "c" (
    window_handle:      ^types.Window   = nil,
    renderer_handle:    ^types.Renderer = nil,
    config:             ^map[string]string = nil,
    indent:             cstring = "  ") -> ^types.Context {

    context = runtime.default_context();
    if window_handle != nil && size_of(window_handle^) != size_of(types.Window) {
        fmt.eprintfln("[ERR]:{}| Window passed is not a valid ygg window: {} vs {} bytes", indent,
            size_of(window_handle^), size_of(types.Window));
        panic("Config Error");
    }

    if renderer_handle != nil && size_of(renderer_handle^) != size_of(types.Renderer) {
        fmt.eprintfln("[ERR]:{}| Renderer passed is not a valid ygg renderer: {} vs {} bytes", indent,
            size_of(renderer_handle^), size_of(types.Renderer));
        panic("Config Error");
    }

    if config != nil && size_of(config^) != 32 {
        fmt.eprintfln("[ERR]:{}| Config map passed is not a valid Odin map: {} vs {} bytes", indent,
            size_of(config^), 32);
        panic("Config Error");
    }

    ctx_ptr := new_clone(types.Context {
        window     = window_handle,
        root       = nil,
        last_node  = nil,
        config     = config != nil ? config^ : utils.default_config(),
        cursor     = { 0, 0 },
        renderer   = renderer_handle,
        _context   = context,
        _arena     = new(vmem.Arena)
    });

    // This library does not free its individual dynamic allocs. Just put the whole context in an arena and no leaking
    // will happen as long as you destroy it.
    if err := vmem.arena_init_growing(ctx_ptr._arena, 1 * mem.Gigabyte); err != vmem.Allocator_Error.None {
        fmt.eprintfln("[ERR]:{} --- Cannot create context: Arena alloc error: {}", indent, err);
        free(ctx_ptr._arena);
        free(ctx_ptr);
        panic("Arena Alloc Error");
    }

    ctx_ptr._context.allocator = vmem.arena_allocator(ctx_ptr._arena);
    context = ctx_ptr._context;

    new_indent   := strings.concatenate({string(indent), "  "});
    new_c_indent := strings.clone_to_cstring(new_indent);

    if config == nil {
        sanitized_config, error := sanitize_config(indent = new_indent);
        if error != types.ConfigError.None {
            fmt.eprintfln("[ERR]:  --- Error creating context: {}", error);
            panic("Config Error");
        }
        ctx_ptr.config = sanitized_config;
    }

    level : types.LogLevel = utils.into_debug(ctx_ptr.config["log_level"]);
    ctx_ptr.log_level = level;

    if level != types.LogLevel.None do fmt.printfln("[INFO]:{}| Creating context ... ", indent);

    if ctx_ptr.window == nil && !utils.into_bool(ctx_ptr.config["headless"]) {
        window := create_window("Yggdrasil (Debug)", indent = new_c_indent);
        ctx_ptr.window = new_clone(window);
    }

    if ctx_ptr.window != nil && ctx_ptr.renderer == nil {
        if level >= types.LogLevel.Verbose {
            fmt.printfln("[WARN]:  --- No renderer handle found, creating one ...");
        }
        renderer := create_renderer(ctx_ptr.window, indent = new_c_indent);
        ctx_ptr.renderer = new_clone(renderer);
    }

    // Setup default font glyphs for text rendering
    init_font(ctx_ptr, indent = new_c_indent);

    if level >= types.LogLevel.Verbose {
        str := utils.into_str(ctx_ptr, "           ");
        fmt.printfln("[INFO]:{0}--- Done (\n{2} {1}\n         )", indent, str, "          ");
    } else {
        fmt.printfln("[INFO]:{}--- Done", indent);
    }

    return ctx_ptr;
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
@(export, link_prefix="ygg_")
reset_context :: proc "c" (ctx: ^types.Context, indent: cstring = "  ") {
    assert_contextless(ctx != nil, "[ERR]:\t| Error resetting context: Context is nil!");

    ctx._context = runtime.default_context();
    context = ctx._context;

    level: types.LogLevel = ctx.log_level;
    if level >= types.LogLevel.Normal {
        str := utils.into_str(ctx);
        fmt.printfln("[INFO]:{}| Resetting context (%p) ... :\n{}", indent, ctx, str);
    }

    ctx.log_level = types.LogLevel.None;

    if len(ctx.config) > 0 {
        delete_map(ctx.config);
        ctx.config = {};
    }
    ctx.root = nil;
    ctx.window = nil;
    ctx.cursor = { 0, 0 };
    ctx.last_node = nil;
    ctx.config = {};

    // Init offset and zero memory
    vmem.arena_destroy(ctx._arena);

    if level >= types.LogLevel.Normal {
        str := utils.into_str(ctx, "    ");
        fmt.printfln("[INFO]:{}--- Done (%p) :\n{}", indent, ctx, str);
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
@(export, link_prefix="ygg_")
destroy_context :: proc "c" (ctx: ^types.Context, indent: cstring = "  ") {
    assert_contextless(ctx != nil, "[ERR]:\tCannot destroy context: Ygg Context is nil. Did you forget to call " +
    "'create_context(...)' ?");

    context = runtime.default_context();
    level: types.LogLevel = ctx.log_level;

    if level >= types.LogLevel.Normal do fmt.printfln("[INFO]:{}| Destroying context (%p) ...", indent, ctx);

    odin_indent := string(indent);
    new_indent  := strings.concatenate({ odin_indent, "  " });
    c_indent    := strings.clone_to_cstring(new_indent);

    if ctx.root != nil      do destroy_node(ctx, ctx.root.id, indent = c_indent);
    if ctx.renderer != nil  do destroy_renderer(ctx.renderer, c_indent);
    if ctx.window != nil    do destroy_window(ctx.window, c_indent);

    if level >= types.LogLevel.Normal do fmt.printfln("[INFO]:{}--- Done", indent);

    vmem.arena_destroy(ctx._arena);
    free(ctx._arena);
    free(ctx);
}