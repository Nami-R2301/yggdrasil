#+feature dynamic-literals
package examples;

import fmt  "core:fmt";
import glfw "vendor:glfw";
import gl   "vendor:OpenGL";

import ygg   "../src";
import rt    "../src/retained";
import types "../src/types";
import utils "../src/utils";

main :: proc () {
    using types;
    using utils;

    result_window := ygg.create_window("Retained Mode");
    window_handle := unwrap(result_window.opt);

    result_renderer := ygg.create_renderer(bg_color = 0x222222);
    renderer_handle := unwrap(result_renderer.opt);

    // Unlike the immediate mode example, in the retained mode API you MUST provide the window & renderer handles to
    // 'create_context()' IF you plan on endering your nodes onto a surface.
    ctx_result := rt.create_context(window_handle = &window_handle, renderer_handle = &renderer_handle, config = {
        "log_level" = "vvv"
    });
    ctx := unwrap(ctx_result.opt);

    head  := rt.create_node(&ctx, tag = "head");
    title := rt.create_node(&ctx, tag = "title", parent = &head);

    node_error := rt.attach_node(&ctx, head);
    node_error  = rt.attach_node(&ctx, title);

    buffer_result := rt.create_buffer(BufferType.vbo);
    buffer := unwrap(buffer_result.opt);

    // Serialize the node styles into recognizable draw properties and compile the vertices into compact bytes.
    serde_result  := rt.serialize_nodes({ head, title });

    // Set the buffer to its respective type, bind it, and optionally init with given data.
    buffer_error  := rt.prepare_buffer(&buffer, data = unwrap(serde_result.opt));

    // IMPORTANT: Add the newly created buffer into the main rendering pipeline.
    rt.attach_buffer(&renderer_handle, &buffer);

    headless_mode : bool = into_bool(ctx.config["headless"]);
    if !headless_mode {
        for bool(!glfw.WindowShouldClose(ctx.window.glfw_handle)) {
            glfw.PollEvents();
            // Bind the shader, vao, and draw the vertices in the main vbo containing all node data.
            rt.render_now(ctx.renderer);
            glfw.SwapBuffers(ctx.window.glfw_handle);
        }
    }
}

