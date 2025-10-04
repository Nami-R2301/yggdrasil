package examples;

import "vendor:raylib";
import "vendor:glfw";
import "core:fmt";

import ygg "../src";
import types "../src/types";
import utils "../src/utils";

main2 :: proc () {
    using types;
    using utils;

    result := ygg.init_context();
    assert(into_bool(result), "Error initializing context");
    ctx := unwrap(result.opt);
    defer ygg.terminate_context(&ctx);

    // Build an HTML like tree and avoid explicitely passing parent nodes to children and having to
    // manually detach nodes from the context tree. If the config has rendering enabled, they will
    // automatically be rendered with the correct styling passed.

    // Main loop - all nodes will be re-rendered on each frame (immediate mode).
    for bool(!glfw.WindowShouldClose(ctx.window.glfw_handle)) {
        glfw.PollEvents();
        glfw.SwapBuffers(ctx.window.glfw_handle);

        // Example tree:
        // <root>  -> Root gets automatically added when initializing context
        //   <head>
        //     <link/>
        //     <link/>
        //   </head>
        // </root>

        if result := ygg.head(&ctx); into_bool(result) {
            // Avoid writing end_node(...) for inline nodes with `is_inline = true`.
            _ = ygg.link(&ctx, is_inline = true);
            _ = ygg.link(&ctx, is_inline = true);

            _ = ygg.end_node(&ctx, unwrap(result.opt));  // </head>
        }

        // Once every node has met their respective end, drawing will commence, otherwise runtime
        // error is generated.
    }
}