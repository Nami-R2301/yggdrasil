package retained;

import queue "core:container/queue";
import gl "vendor:OpenGL";

import types "../types";

////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////// RETAINED API ///////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////

//TODO: Create renderer with default features.
create_renderer :: proc (
type:       types.RendererType = types.RendererType.OpenGL,
bg_color:   u32 = 0x181818) -> (types.RendererError, types.Option(types.Renderer))  {
    panic("Unimplemented");
}

// TODO: Deallocate and free up buffers in the pipeline for graceful shutdown.
destroy_renderer :: proc (renderer: ^types.Renderer) -> types.RendererError {
    queue.destroy(&renderer.node_queue);

    gl.DeleteBuffers(1, &renderer.vbo.id);
    gl.DeleteBuffers(1, &renderer.vao.id);
    gl.DeleteBuffers(1, &renderer.ibo.id);
    gl.DeleteBuffers(1, ([^]u32)(raw_data(renderer.ubos)));

    delete_dynamic_array(renderer.ubos);
    delete_dynamic_array(renderer.textures);
    delete_dynamic_array(renderer.framebuffers);

    return types.RendererError.None;
}

