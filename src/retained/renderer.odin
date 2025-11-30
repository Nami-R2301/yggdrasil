package retained;

import fmt "core:fmt";
import gl "vendor:OpenGL";

import types "../types";
import utils "../utils";

////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////// RETAINED API ///////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////

// TODO: Load shader program, init 2D settings, draw all vertices, and revert 2D settings in case renderer is used elsewhere.
render_now :: proc (renderer_ptr: ^types.Renderer, indent: string = "  ") {
    assert(renderer_ptr != nil &&  renderer_ptr.state != types.RendererState.Prepared,
    "Error when rendering: No renderer setup! Did you forget to first call 'prepare_buffer()'?");

    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

    last_program := get_last_program();
    last_vbo := get_last_vbo();
    last_vao := get_last_vao();
    last_ibo := get_last_ibo();

    // Bind buffers and use UI shader.
    gl.UseProgram(renderer_ptr.program);
    gl.BindVertexArray(renderer_ptr.vao.id);
    gl.BindBuffer(gl.ARRAY_BUFFER, renderer_ptr.vbo.id);
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, renderer_ptr.ibo.id);

    gl.DrawArrays(gl.TRIANGLES, 0, i32(renderer_ptr.vbo.count));

    // Revert buffers and program.
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, utils.unwrap_or(last_ibo.opt, 0));
    gl.BindBuffer(gl.ARRAY_BUFFER, utils.unwrap_or(last_vbo.opt, 0));
    gl.BindVertexArray(utils.unwrap_or(last_vao.opt, 0));
    gl.UseProgram(utils.unwrap_or(last_program.opt, 0));
}

match_buffer :: proc (renderer_ptr: ^types.Renderer, buffer_type: types.BufferType) -> ^types.Buffer {
    switch buffer_type {
    case types.BufferType.Vbo:
        return &renderer_ptr.vbo;
    case types.BufferType.Vao:
        return &renderer_ptr.vao;
    case types.BufferType.Ibo:
        return &renderer_ptr.ibo;
    case types.BufferType.Ubo:
        return raw_data(renderer_ptr.ubos);
    case types.BufferType.Framebuffer:
        return raw_data(renderer_ptr.framebuffers);
    }

    panic(fmt.aprintf("Error matching buffer '{}': Buffer type unsupported!", buffer_type));
}

find_buffer :: proc (renderer_ptr: ^types.Renderer, buffer_type: types.BufferType, id: u32, indent: string = "  ") -> ^types.Buffer {
    assert(renderer_ptr != nil, "Error when finding buffer: No renderer found! Did you forget to first call 'create_renderer()'?");

    fmt.printf("[INFO]:{}| Finding buffer of type '{}' and id '{}' ... ", indent, buffer_type, id);
    buffer_ptr := match_buffer(renderer_ptr, buffer_type);

    if buffer_ptr.id != id {
        fmt.printfln("\n[ERR]:{}--- Error finding buffer: Buffer not found", indent);
        return nil;
    }

    fmt.printfln("Done ('{}')", id);
    return buffer_ptr;
}