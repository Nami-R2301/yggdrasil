package retained;

import queue "core:container/queue";
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

_create_buffer :: proc (
renderer_ptr:   ^types.Renderer,
buffer_type:    types.BufferType,
capacity:       u64 = 1_000_000,
indent:         string = "  ") -> types.Result(types.Buffer) {
    using types;
    using utils;

    assert(renderer_ptr != nil, "Error when creating buffer: No renderer setup! Did you forget to first call '_create_renderer()'?");

    buffer := types.Buffer {
        id = 0,
        type = buffer_type,
        size = 0,
        count = 0,
        capacity = capacity
    };

    fmt.printfln("[INFO]:{}| Creating buffer of type '{}' and capacity of '{}' ...", indent, buffer_type, capacity);

    inner_indent := strings.concatenate({indent, "  "});
    error := _validate_buffer_params(buffer, inner_indent);
    delete_string(inner_indent);

    if error != BufferError.None {
        return { error = error, opt = none(Buffer) };
    }

    gl.CreateBuffers(1, &buffer.id);

    fmt.printfln("[INFO]:{}--- Done", indent);
    return { error = BufferError.None, opt = some(buffer) };
}

_destroy_buffer :: proc (
renderer_ptr:   ^types.Renderer,
buffer_type:    types.BufferType,
id:             u32,
indent:         string = "  ") -> types.BufferError {
    using types;

    assert(renderer_ptr != nil, "Error when destroying buffer: No renderer setup! Did you forget to first call '_create_renderer()'?");
    fmt.printfln("[INFO]:{}| Destroying buffer of type '{}' ('') ...", indent, buffer_type, id);

    id_ptr := _find_buffer(renderer_ptr, buffer_type, id);
    if id_ptr == nil {
        return BufferError.BufferNotFound;
    }

    gl.DeleteBuffers(1, &id_ptr.id);

    fmt.printfln("[INFO]:{}--- Done", indent);
    return BufferError.None;
}

_render_now :: proc (renderer_ptr: ^types.Renderer, indent: string = "  ") {
    assert(renderer_ptr != nil, "Error when rendering: No renderer setup at the moment of drawing! Did you forget to first call '_create_renderer()'?");

    gl.DrawArrays(gl.TRIANGLES, 0, i32(_get_buffer_len(renderer_ptr, types.BufferType.vbo)));
}

_prepare_buffer :: proc (renderer_ptr: ^types.Renderer, indent: string = "  ") {
    assert(renderer_ptr != nil, "Error when creating buffer: No renderer setup! Did you forget to first call '_create_renderer()'?");
    panic("Unimplemented");
}


_append_buffer :: proc (renderer_ptr: ^types.Renderer, indent: string = "  ") {
    assert(renderer_ptr != nil, "Error when creating buffer: No renderer setup! Did you forget to first call '_create_renderer()'?");
    panic("Unimplemented");
}

_shrink_buffer :: proc (renderer_ptr: ^types.Renderer, indent: string = "  ") {
    assert(renderer_ptr != nil, "Error when creating buffer: No renderer setup! Did you forget to first call '_create_renderer()'?");
    panic("Unimplemented");
}

_migrate_buffer :: proc (renderer_ptr: ^types.Renderer, indent: string = "  ") {
    assert(renderer_ptr != nil, "Error when creating buffer: No renderer setup! Did you forget to first call '_create_renderer()'?");
    panic("Unimplemented");
}

_reset_buffer :: proc (renderer_ptr: ^types.Renderer, indent: string = "  ") {
    assert(renderer_ptr != nil, "Error when creating buffer: No renderer setup! Did you forget to first call '_create_renderer()'?");
    panic("Unimplemented");
}

_get_buffer_len :: proc (renderer_ptr: ^types.Renderer, buffer_type: types.BufferType) -> u64 {
    buffer_ptr := _match_buffer(renderer_ptr, buffer_type);

    return buffer_ptr.count;
}

_validate_buffer_params :: proc (buffer: types.Buffer, indent: string = "  ") -> types.BufferError {
    if buffer.capacity >= C_VBO_SIZE_LIMIT {
        fmt.printfln("[ERR]:{}--- Buffer capacity '{}' for ('{}') exceeds the maximum allowed bytes ({})", indent,
        buffer.capacity, buffer.id, C_VBO_SIZE_LIMIT);
        return types.BufferError.ExceededMaxSize;
    }

    return types.BufferError.None;
}

_match_buffer :: proc (renderer_ptr: ^types.Renderer, buffer_type: types.BufferType) -> ^types.Buffer {
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

_find_buffer :: proc (renderer_ptr: ^types.Renderer, buffer_type: types.BufferType, id: u32, indent: string = "  ") -> ^types.Buffer {
    assert(renderer_ptr != nil, "Error when finding buffer: No renderer setup! Did you forget to first call '_create_renderer()'?");

    fmt.printf("[INFO]:{}| Finding buffer of type '{}' and id '{}' ... ", indent, buffer_type, id);
    buffer_ptr := _match_buffer(renderer_ptr, buffer_type);

    if buffer_ptr.id != id {
        fmt.printfln("\n[ERR]:{}--- Error finding buffer: Buffer not found", indent);
        return nil;
    }

    fmt.printfln("Done ('{}')", id);
    return buffer_ptr;
}

