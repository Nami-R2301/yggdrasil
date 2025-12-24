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

    ctx, error := im.init_context(custom_config = {
        "log_level" = "v"
    });
    defer im.terminate_context();

    context.user_ptr = &ctx;

    // Main loop - all nodes will be re-rendered on each frame (immediate mode).
    for ygg.is_window_running(ctx.window) {
        im.begin_frame();  // Reset nodes and start capturing new frame layout from here.

        // <h1/>
        im.title(text = "Hello World!", is_inline = true, style = {
            "position"   = utils.some("absolute"),
            "width"      = utils.some("100%"),
            "height"     = utils.some("100%"),
            "center"     = utils.some("true"),  // Flex + justify-center + items-center + m-auto.
            "font-size"  = utils.some("32px")
        });

        im.end_frame();  // Validate nodes & draw if rendering is toggled on.
    }
}

retained :: proc () {
    using types;
    using utils;

    window_handle,   _ := ygg.create_window("Retained Mode");
    renderer_handle, _ := ygg.create_renderer();

    // Unlike the immediate mode example, in the retained mode API you MUST provide the window & renderer handles to
    // 'create_context()' IF you plan on endering your nodes onto a surface.
    ctx, error := rt.create_context(window_handle = &window_handle, renderer_handle = &renderer_handle, config = {
        "log_level" = "v",
    });
    context.user_ptr = &ctx;
    defer rt.destroy_context();

    head, _  := rt.create_node(tag = "head");
    title, _ := rt.create_node(tag = "title", parent = &head);

    node_error := rt.attach_node(head);
    node_error  = rt.attach_node(title);

    // Serialize the node styles into recognizable draw properties and compile the vertices into compact bytes.
    // serde_result  := rt.serialize_nodes(ctx.root);

    err := ygg.draw_box(100, 100, 0, size = 400);
    assert(err == RendererError.None, "[ERR]:\tError creating box");

    // Create UI Layer
    fbo        := ygg.create_framebuffer(ctx.window.dimensions[0], ctx.window.dimensions[1]);
    fbo_error  := ygg.prepare_buffer(&fbo);
    assert(fbo_error == BufferError.None, "[ERR]:\tError preparing Framebuffer");

    for ygg.is_window_running(ctx.window) {
        glfw.PollEvents();
        // Bind the shader, vao, and draw the vertices in the main vbo containing all node data.
        ygg.render_now();
        glfw.SwapBuffers(ctx.window.glfw_handle);
    }
}