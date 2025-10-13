#+feature dynamic-literals
package examples;

import fmt  "core:fmt";
import glfw "vendor:glfw";

import im    "../src/immediate";
import types "../src/types";
import utils "../src/utils";

immediate :: proc () {
    using types;
    using utils;

    //result_window := ygg.create_window("Immediate Mode");
    //window_handle := unwrap(result_window.opt);

    //result_renderer := ygg.create_renderer(bg_color = 0x222222);
    //renderer_handle := unwrap(renderer_opt);

    // OPTIONAL: You can create your customized window and renderer, passed into 'init_context()'. If this function
    // receives nothing for those two components, it will default to a 800x600 window with OpenGL as its renderer API.
    // result := im.init_context(window_handle = &window_handle, renderer_handle = &renderer_handle);

    result := im.init_context(custom_config = {
        "log_level" = "",
        "headless" = "true",
    });
    ctx := unwrap(result.opt);
    defer im.terminate_context(&ctx);

    // Main loop - all nodes will be re-rendered on each frame (immediate mode).
    for bool(!glfw.WindowShouldClose(ctx.window.glfw_handle)) {
        // Example tree:
        // <root>
        //   <head>
        //     <h1/>
        //   </head>
        // </root>

        im.begin_frame(&ctx);  // Reset nodes and start capturing new frame layout from here.

        im.root(&ctx);
        {
            im.head(&ctx);
            {
                // Avoid writing end_node(...) for inline nodes with `is_inline = true`.
                result   := im.title(&ctx, "Hello World!", is_inline = true);
                node_ptr := unwrap(result.opt);

                // Position at center of the screen with a slighty bigger font.
                node_ptr.style["position"]      = some("absolute");
                node_ptr.style["width"]         = some("100%");
                node_ptr.style["height"]        = some("100%");
                node_ptr.style["center"]        = some("1");    // Flex + justify-center + items-center + m-auto.
                node_ptr.style["font-size"]     = some("32px"); // <h1>
            }
            im.end_node(&ctx, "head");  // </head>
        }
        im.end_node(&ctx, "root");  // </root>

        im.end_frame(&ctx);  // Validate nodes & draw if rendering is toggled on.
    }
}