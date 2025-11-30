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

    result_window := ygg.create_window("Retained Mode");
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
    // serde_result  := rt.serialize_nodes(ctx.root);

    vertices := [3]Vertex{
        // Vertex 1: Bottom Left (Red)
        {
            entity_id    = 1,
            position     = { -0.5, -0.5, 0.0 },
            color        = { 1.0, 0.0, 0.0, 1.0 },
            tex_coords   = { 0.0, 0.0 },
        },
        // Vertex 2: Bottom Right (Green)
        {
            entity_id    = 1,
            position     = { 0.5, -0.5, 0.0 },
            color        = { 0.0, 1.0, 0.0, 1.0 },
            tex_coords   = { 1.0, 0.0 },
        },
        // Vertex 3: Top Center (Blue)
        {
            entity_id    = 1,
            position     = { 0.0, 0.5, 0.0 },
            color        = { 0.0, 0.0, 1.0, 1.0 },
            tex_coords   = { 0.5, 1.0 },
        },
    }

    // Allocate space in the buffer, bind it to its respective type
    vbo_error  := ygg.prepare_buffer(&renderer_handle.vbo, Data { ptr = &vertices, count = 3, size = size_of(Vertex) });
    assert(vbo_error == BufferError.None, "[ERR]:\tError preparing VBO buffer");

    for ygg.is_window_running(&ctx) {
        glfw.PollEvents();
        // Bind the shader, vao, and draw the vertices in the main vbo containing all node data.
        ygg.render_now(ctx.renderer);
        glfw.SwapBuffers(ctx.window.glfw_handle);
    }
}

