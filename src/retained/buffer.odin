package retained;

import strings "core:strings";
import gl "vendor:OpenGL";
import fmt "core:fmt";

import types "../types";
import utils "../utils";

C_VBO_SIZE_LIMIT: u64 = 10_000_000;

////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////// RETAINED API ///////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////

create_buffer :: proc (
    buffer_type:    types.BufferType,
    capacity:       u64 = 1_000_000,
    indent:         string = "  ") -> types.Result(types.Buffer) {
    using types;
    using utils;

    buffer := types.Buffer {
        id = 0,
        type = buffer_type,
        size = 0,
        count = 0,
        capacity = capacity
    };

    fmt.printfln("[INFO]:{}| Creating buffer of type '{}' and capacity of '{}' ...", indent, buffer_type, capacity);

    inner_indent := strings.concatenate({indent, "  "});
    error := validate_buffer_params(buffer, inner_indent);
    delete_string(inner_indent);

    if error != BufferError.None {
        return { error = error, opt = none(Buffer) };
    }

    gl.CreateBuffers(1, &buffer.id);

    fmt.printfln("[INFO]:{}--- Done", indent);
    return { error = BufferError.None, opt = some(buffer) };
}

destroy_buffer :: proc (
    renderer_ptr:   ^types.Renderer,
    buffer_type:    types.BufferType,
    id:             u32,
    indent:         string = "  ") -> types.BufferError {
    using types;

    assert(renderer_ptr != nil, "Error when destroying buffer: No renderer setup! Did you forget to first call '_create_renderer()'?");
    fmt.printfln("[INFO]:{}| Destroying buffer of type '{}' ('') ...", indent, buffer_type, id);

    id_ptr := find_buffer(renderer_ptr, buffer_type, id);
    if id_ptr == nil {
        return BufferError.BufferNotFound;
    }

    gl.DeleteBuffers(1, &id_ptr.id);

    fmt.printfln("[INFO]:{}--- Done", indent);
    return BufferError.None;
}

// TODO: Clear out buffer data, but keep capacity intact in case the space is reused later.
reset_buffer :: proc (buffer: ^types.Buffer, indent: string = "  ") {
    panic("Unimplemented");
}

// TODO: Load shader program, init 2D settings, draw all vertices, and revert 2D settings in case renderer is used elsewhere.
render_now :: proc (renderer_ptr: ^types.Renderer, indent: string = "  ") {
    assert(renderer_ptr != nil, "Error when rendering: No renderer setup! Did you forget to first call '_create_renderer()'?");

    gl.DrawArrays(gl.TRIANGLES, 0, i32(renderer_ptr.vbo.count));
}

// TODO: Bind buffer for static drawing into VRAM in its appropriate location with data passed optionally to init.
prepare_buffer :: proc (
    buffer:         ^types.Buffer,
    data:           []byte = {},
    indent:         string = "  ") -> types.BufferError {
    panic("Unimplemented");
}

// TODO: Put buffer in draw pipeline to render later, depending on the type.
attach_buffer :: proc (renderer_ptr: ^types.Renderer, buffer: ^types.Buffer, indent: string = "  ") {
    assert(renderer_ptr != nil, "Error when attaching buffer: No renderer setup! Did you forget to first call '_create_renderer()'?");
    panic("Unimplemented");
}

// TODO: Pack node styling and properties into appropriate uniforms and vertex data to pass to shader later on.
serialize_nodes :: proc (node: []types.Node, indent: string = "  ") -> types.Result([]byte) {
    panic("Unimplemented");
}

// TODO: Dynamically grow buffer in the event the data is dynamic. Might have to redo the buffer with DYNAMIC_DRAW?
grow_buffer :: proc (
    buffer:         ^types.Buffer,
    data:           []byte,
    indent:         string = "  ") -> types.BufferError {
    panic("Unimplemented");
}

// TODO: Dynamically shrink buffer in the event the data is dynamic. Might have to redo the buffer with DYNAMIC_DRAW?
shrink_buffer :: proc (buffer: ^types.Buffer, shrink_size_byte: u64, indent: string = "  ") {
    panic("Unimplemented");
}

// TODO: Copy all buffer contents into a new buffer of the same type, and support coying slices too.
copy_buffer :: proc (buffer: ^types.Buffer, buffer_size_byte: u64, buffer_count_vertex: u64, indent: string = "  ") {
    panic("Unimplemented");
}

// TODO: Add more constraints depending on buffer type for maximum compatibility, since older versions have other requirements.
validate_buffer_params :: proc (buffer: types.Buffer, indent: string = "  ") -> types.BufferError {
    if buffer.capacity >= C_VBO_SIZE_LIMIT {
        fmt.printfln("[ERR]:{}--- Buffer capacity '{}' for ('{}') exceeds the maximum allowed bytes ({})", indent,
        buffer.capacity, buffer.id, C_VBO_SIZE_LIMIT);
        return types.BufferError.ExceededMaxSize;
    }

    return types.BufferError.None;
}

match_buffer :: proc (renderer_ptr: ^types.Renderer, buffer_type: types.BufferType) -> ^types.Buffer {
    switch buffer_type {
    case types.BufferType.vbo:
        return &renderer_ptr.vbo;
    case types.BufferType.vao:
        return &renderer_ptr.vao;
    case types.BufferType.ibo:
        return &renderer_ptr.ibo;
    case types.BufferType.ubo:
        return raw_data(renderer_ptr.ubos);
    case types.BufferType.framebuffer:
        return raw_data(renderer_ptr.framebuffers);
    case types.BufferType.texture:
        return raw_data(renderer_ptr.textures);
    }

    panic("Error matching buffer: Buffer type unsupported!");
}

find_buffer :: proc (renderer_ptr: ^types.Renderer, buffer_type: types.BufferType, id: u32, indent: string = "  ") -> ^types.Buffer {
    assert(renderer_ptr != nil, "Error when finding buffer: No renderer setup! Did you forget to first call '_create_renderer()'?");

    fmt.printf("[INFO]:{}| Finding buffer of type '{}' and id '{}' ... ", indent, buffer_type, id);
    buffer_ptr := match_buffer(renderer_ptr, buffer_type);

    if buffer_ptr.id != id {
        fmt.printfln("\n[ERR]:{}--- Error finding buffer: Buffer not found", indent);
        return nil;
    }

    fmt.printfln("Done ('{}')", id);
    return buffer_ptr;
}

