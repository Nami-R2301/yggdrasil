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

    // Manual configs.
    temp_config : map[string]string = { };

    temp_config["log_level"] = "vvv";      // Log Verbosity. Defaults to normal or 'v'.
    temp_config["log_file"] = "logs.txt"; // Where do we log the app's logs.
    temp_config["headless"] = "";         // If we plan on using a window. Defaults to a falsy value.
    temp_config["optimization"] = "speed";    // Optimization level. This will disable stdout logging and batch renderer commands if supported for speed. Defaults to debug.
    temp_config["cache"] = "";         // If we want to enable caching of nodes. Defaults to a truthy value.
    temp_config["renderer"] = "";         // If we plan on rendering nodes. Defaults to a truthy value.

    result_window := ygg._create_window("Low Level Example");
    assert(result_window.error == WindowError.None, "Error creating window");
    window_handle := unwrap(result_window.opt);

    //  renderer_error, renderer_opt := ygg._create_renderer(bg_color = 0x222222);
    //  assert(renderer_error == RendererError.None, "Error creating renderer");
    //  renderer_handle := unwrap(renderer_opt);

    result_ctx := ygg._create_context(window_handle = &window_handle, config = temp_config);
    assert(into_bool(result_ctx), "Error creating main context");
    ctx := unwrap(result_ctx.opt);
    defer ygg._destroy_context(&ctx);

    head := ygg._create_node(&ctx, tag = "head");
    link := ygg._create_node(&ctx, tag = "link");
    link2 := ygg._create_node(&ctx, tag = "link", parent = &head);

    error := ygg._attach_node(&ctx, head);
    error = ygg._attach_node(&ctx, link);
    error = ygg._attach_node(&ctx, link2);

    node := ygg.find_node(&ctx, 2);
    ygg.print_nodes(node);

    headless_mode : bool = into_bool(ctx.config["headless"]);
    if !headless_mode {
        for bool(!glfw.WindowShouldClose(ctx.window.glfw_handle)) {
            glfw.PollEvents();
            glfw.SwapBuffers(ctx.window.glfw_handle);
        }
    }
}

