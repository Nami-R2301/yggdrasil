#+feature dynamic-literals
package examples;

import fmt  "core:fmt";
import glfw "vendor:glfw";

import ygg "../src";
import im    "../src/immediate";
import types "../src/types";
import utils "../src/utils";

immediate :: proc () {
    using types;

    //result_window := ygg.create_window("Immediate Mode");
    //window_handle := unwrap(result_window.opt);

    //result_renderer := ygg.create_renderer();
    //renderer_handle := unwrap(renderer_opt);

    // OPTIONAL: You can create your customized window and renderer, passed into 'init_context()'. If this function
    // receives nothing for those two components, it will default to a 800x600 window with OpenGL as its renderer API.
    // result := im.init_context(window_handle = &window_handle, renderer_handle = &renderer_handle);

    result := im.init_context(custom_config = {
        "log_level" = "v"
    });
    ctx := utils.unwrap(result.opt);
    defer im.terminate_context(&ctx);

    // Main loop - all nodes will be re-rendered on each frame (immediate mode).
    for ygg.is_window_running(&ctx) {
        // Example tree:
        // <root>
        //   <head>
        //     <h1/>
        //   </head>
        // </root>

        im.begin_frame(&ctx);  // Reset nodes and start capturing new frame layout from here.

        im.root(&ctx);  // <root>
        {
            im.head(&ctx);  // <head>
            {
                // <h1/>
                im.title(&ctx, text = "Hello World!", is_inline = true, style = {
                    "position"   = utils.some("absolute"),
                    "width"      = utils.some("100%"),
                    "height"     = utils.some("100%"),
                    "center"     = utils.some("1"),  // Flex + justify-center + items-center + m-auto.
                    "font-size"  = utils.some("32px")
                });
            }
            im.end_node(&ctx, "head");  // </head>
        }
        im.end_node(&ctx, "root");  // </root>

        im.end_frame(&ctx);  // Validate nodes & draw if rendering is toggled on.
    }
}