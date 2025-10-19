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

    gl.GenBuffers(1, &buffer.id);

    fmt.printfln("[INFO]:{}--- Done", indent);
    return { error = BufferError.None, opt = some(buffer) };
}

destroy_buffer :: proc (
    buffer_type:    types.BufferType,
    id:             u32,
    indent:         string = "  ") -> types.BufferError {
    using types;
    fmt.printfln("[INFO]:{}| Destroying buffer of type '{}' ('') ...", indent, buffer_type, id);

    id_ptr := id;
    gl.DeleteBuffers(1, &id_ptr);

    fmt.printfln("[INFO]:{}--- Done", indent);
    return BufferError.None;
}

// TODO: Clear out buffer data, but keep capacity intact in case the space is reused later.
reset_buffer :: proc (buffer: ^types.Buffer, indent: string = "  ") {
    panic("Unimplemented");
}

// TODO: Bind buffer for static drawing into VRAM in its appropriate location with data passed optionally to init.
prepare_buffer :: proc (
    buffer:         ^types.Buffer,
    data:           []byte = {},
    indent:         string = "  ") -> types.BufferError {
    panic("Unimplemented");
}

// TODO: Pack node styling and properties into appropriate uniforms and vertex data to pass to shader later on.
serialize_nodes :: proc (root: ^types.Node, indent: string = "  ") -> types.Result([]byte) {
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

get_last_program :: proc () -> types.Result(u32) {
    program_id: i32 = 0;

    gl.GetIntegeri_v(gl.CURRENT_PROGRAM, 0, &program_id);
    if program_id <= 0 {
        return { error = types.ProgramError.ProgramNotFound, opt = utils.none(u32) };
    }

    return { error = types.ProgramError.None, opt = utils.some(u32(program_id)) };
}

get_last_vbo :: proc () -> types.Result(u32) {
    vbo_id: i32 = 0;

    gl.GetIntegeri_v(gl.ARRAY_BUFFER_BINDING, 0, &vbo_id);
    if vbo_id <= 0 {
        return { error = types.BufferError.BufferNotFound, opt = utils.none(u32) };
    }

    return { error = types.BufferError.None, opt = utils.some(u32(vbo_id)) };
}

get_last_ibo :: proc () -> types.Result(u32) {
    ibo_id: i32 = 0;

    gl.GetIntegerv(gl.ELEMENT_ARRAY_BUFFER_BINDING, &ibo_id);
    if ibo_id <= 0 {
        return { error = types.BufferError.BufferNotFound, opt = utils.none(u32) };
    }

    return { error = types.BufferError.None, opt = utils.some(u32(ibo_id)) };
}

get_last_vao :: proc () -> types.Result(u32) {
    vao_id: i32 = 0;

    gl.GetIntegerv(gl.VERTEX_ARRAY_BINDING, &vao_id);
    if vao_id <= 0 {
        return { error = types.BufferError.BufferNotFound, opt = utils.none(u32) };
    }

    return { error = types.BufferError.None, opt = utils.some(u32(vao_id)) };
}

