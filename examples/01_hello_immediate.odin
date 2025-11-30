#+feature dynamic-literals
package examples;

import fmt  "core:fmt";
import glfw "vendor:glfw";

import ygg   "../src";
import im    "../src/immediate";
import types "../src/types";
import utils "../src/utils";

immediate :: proc () {
    using types;

    result := im.init_context(custom_config = {
        "log_level" = "v"
    });
    ctx := utils.unwrap(result.opt);
    defer im.terminate_context(&ctx);

    // Main loop - all nodes will be re-rendered on each frame (immediate mode).
    for ygg.is_window_running(&ctx) {
        im.begin_frame(&ctx);  // Reset nodes and start capturing new frame layout from here.

        // <h1/>
        im.title(&ctx, text = "Hello World!", is_inline = true, style = {
            "position"   = utils.some("absolute"),
            "width"      = utils.some("100%"),
            "height"     = utils.some("100%"),
            "center"     = utils.some("true"),  // Flex + justify-center + items-center + m-auto.
            "font-size"  = utils.some("32px")
        });

        im.end_frame(&ctx);  // Validate nodes & draw if rendering is toggled on.
    }
}