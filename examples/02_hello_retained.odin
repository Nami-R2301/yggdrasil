#+feature dynamic-literals
package examples;

import fmt  "core:fmt";
import glfw "vendor:glfw";
import gl   "vendor:OpenGL";

import ygg   "../src";
import rt    "../src/retained";
import types "../src/types";
import utils "../src/utils";

retained :: proc () {
    using types;
    using utils;

    result_window := ygg.create_window("Retained Mode", dimensions = {1920, 1080});
    window_handle := unwrap(result_window.opt);

    result_renderer := ygg.create_renderer();
    renderer_handle := unwrap(result_renderer.opt);

    // Unlike the immediate mode example, in the retained mode API you MUST provide the window & renderer handles to
    // 'create_context()' IF you plan on endering your nodes onto a surface.
    ctx_result := rt.create_context(window_handle = &window_handle, renderer_handle = &renderer_handle, config = {
        "log_level" = "v",
    });
    ctx := unwrap(ctx_result.opt);
    defer rt.destroy_context(&ctx);

    head  := rt.create_node(&ctx, tag = "head");
    title := rt.create_node(&ctx, tag = "title", parent = &head);

    node_error := rt.attach_node(&ctx, head);
    node_error  = rt.attach_node(&ctx, title);

    // Serialize the node styles into recognizable draw properties and compile the vertices into compact bytes.
    serde_result  := rt.serialize_nodes(ctx.root);

    // Allocate space in the buffer, bind it to its respective type, and optionally init with given data.
    buffer_error  := rt.prepare_buffer(&renderer_handle.vbo, data = unwrap(serde_result.opt));

    for ygg.is_window_running(&ctx) {
        glfw.PollEvents();
        // Bind the shader, vao, and draw the vertices in the main vbo containing all node data.
        rt.render_now(ctx.renderer);
        glfw.SwapBuffers(ctx.window.glfw_handle);
    }
}

