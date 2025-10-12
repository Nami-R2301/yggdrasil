package examples;

import "vendor:raylib";
import "vendor:glfw";
import "core:fmt";

import ygg "../src";
import types "../src/types";
import utils "../src/utils";

main :: proc () {
    using types;
    using utils;

    temp_config: map[string]string = {};

    temp_config["log_level"]    = "vvv";      // Log Verbosity. Defaults to normal or 'v'.
    temp_config["log_file"]     = "logs.txt"; // Where do we log the app's logs.
    temp_config["headless"]     = "";         // If we plan on using a window. Defaults to a falsy value.
    temp_config["optimization"] = "speed";    // Optimization level. This will disable stdout logging and batch renderer commands if supported for speed. Defaults to debug.
    temp_config["cache"]        = "";         // If we want to enable caching of nodes. Defaults to a truthy value.
    temp_config["renderer"]     = "";         // If we plan on rendering nodes. Defaults to a truthy value.

    result := ygg.init_context(custom_config = temp_config);
    assert(into_bool(result), "Error initializing context");
    ctx := unwrap(result.opt);
    defer ygg.terminate_context(&ctx);

    // Build an HTML like tree and avoid explicitely passing parent nodes to children and having to
    // manually detach nodes from the context tree. If the config has rendering enabled, they will
    // automatically be rendered with the correct styling passed.

    // Main loop - all nodes will be re-rendered on each frame (immediate mode).
    for bool(!glfw.WindowShouldClose(ctx.window.glfw_handle)) {
        // Example tree:
        // <root>
        //   <head>
        //     <link/>
        //     <link/>
        //   </head>
        // </root>

        ygg.begin_frame(&ctx);

        ygg.root(&ctx);
        {
            ygg.head(&ctx);
            {
                // Avoid writing end_node(...) for inline nodes with `is_inline = true`.
                ygg.link(&ctx, is_inline = true);
                ygg.link(&ctx, is_inline = true);
            }
            ygg.end_node(&ctx, "head");  // </head>
        }
        ygg.end_node(&ctx, "root");  // </root>

        ygg.end_frame(&ctx);  // Validate nodes & draw if rendering is toggled on
    }
}