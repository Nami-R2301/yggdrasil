#+feature dynamic-literals
package examples;

import fmt      "core:fmt";
import strings  "core:strings";
import glfw     "vendor:glfw";
import mem      "core:mem";

import ygg   "../src";
import im    "../src/immediate";
import rt    "../src/retained";
import types "../src/types";
import utils "../src/utils";

hello_immediate :: proc () {
    using types;

    // This library does not free its individual dynamic allocs. Just put the whole context in an arena and no leaking
    // will happen as long as you destroy it.
    ctx, error := im.init_context(custom_config = {
        "log_level" = "v",
    });
    defer im.terminate_context();

    context.user_ptr = &ctx;

    // Main loop - all nodes will be re-rendered on each frame (immediate mode).
    for ygg.is_window_running(ctx.window) {
        im.begin_frame();  // Reset nodes and start capturing new frame layout from here.

        // <h1/>
        im.text("Hello World!", is_inline = true, style = {
            "position"   = utils.some("absolute"),
            "width"      = utils.some("100%"),
            "height"     = utils.some("100%"),
            "center"     = utils.some("true"),  // Flex + justify-center + items-center + m-auto.
            "font-size"  = utils.some("32px")
        });

        im.end_frame();  // Validate nodes & draw if rendering is toggled on.
    }
}

hello_retained :: proc () {
    using types;
    using utils;

    window_handle,   _ := ygg.create_window("Retained Mode", dimensions = { 2560, 1440 }, refresh_rate = 60);
    renderer_handle, _ := ygg.create_renderer(&window_handle);

    // Unlike the immediate mode example, in the retained mode API you MUST provide the window & renderer handles to
    // 'create_context()' IF you plan on endering your nodes onto a surface.
    ctx, _ := rt.create_context(window_handle = &window_handle, renderer_handle = &renderer_handle, config = {
        "log_level" = "v",
    });
    context.user_ptr = &ctx;
    defer rt.destroy_context();

    ygg.init_font();
    center: Option([2]u32) = utils.some([2]u32{ctx.window.dimensions[0] / 2 - 200, ctx.window.dimensions[1] / 2 - 100});

    rect, _  := rt.box({400, 200}, center, color = {0.0, 0.0, 0.0, 0.0});  // Transparent box
    text, _  := rt.text("Hello World!", &rect);  // Add text in box
    _ = rt.attach_node(rect);
    _ = rt.attach_node(text);
    _ = rt.prepare_nodes_for_render();

    for ygg.is_window_running(ctx.window) {
        glfw.PollEvents();
        // Bind the shader, vao, and draw the vertices in the main vbo containing all node data.
        rt.render_now();
        glfw.SwapBuffers(ctx.window.glfw_handle);
    }
}