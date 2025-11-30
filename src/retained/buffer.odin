package retained;

import gl "vendor:OpenGL";
import fmt "core:fmt";

import types "../types";
import utils "../utils"
import strings "core:strings";

C_VBO_SIZE_LIMIT: u64 = 10_000_000;

////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////// RETAINED API ///////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////

create_framebuffer_attachments :: proc(fbo_width: u32, fbo_height: u32) -> (color_texture: types.Buffer, depth_texture: types.Buffer) {
    // Color
    gl.GenTextures(1, &color_texture.id);
    gl.BindTexture(gl.TEXTURE_2D, color_texture.id);

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_BORDER);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_BORDER);

    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, i32(fbo_width), i32(fbo_height), 0, gl.RGBA, gl.UNSIGNED_BYTE, nil);

    gl.BindTexture(gl.TEXTURE_2D, 0);

    // Depth
    gl.GenTextures(1, &depth_texture.id);
    gl.BindTexture(gl.TEXTURE_2D, depth_texture.id);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.DEPTH_COMPONENT, i32(fbo_width), i32(fbo_height), 0, gl.DEPTH_COMPONENT, gl.UNSIGNED_BYTE, nil);
    gl.BindTexture(gl.TEXTURE_2D, 0);

    return color_texture, depth_texture;
}

create_buffer :: proc (
    buffer_type:    types.BufferType,
    capacity:       u64 = 1_000_000,
    indent:         string = "  ") -> types.Result(types.Buffer) {
    using types;

    buffer := types.Buffer {
        id = 0,
        type = buffer_type,
        size = 0,
        count = 0,
        capacity = capacity,
        length = 0
    };

    fmt.printf("\n[INFO]:{}| Creating buffer of type '{}' and capacity of '{}' ... ", indent, buffer_type, capacity);

    if buffer.capacity > C_VBO_SIZE_LIMIT {
        fmt.printfln("[ERR]:{}--- Buffer capacity '{}' for ('{}') exceeds the maximum allowed bytes ({})", indent,
        buffer.capacity, buffer.id, C_VBO_SIZE_LIMIT);
        return { opt = utils.none(Buffer), error = types.BufferError.ExceededMaxSize };
    }

    switch buffer.type {
        case BufferType.Vao:
            gl.GenVertexArrays(1, &buffer.id);
            break;
        case BufferType.Framebuffer:
            gl.GenFramebuffers(1, &buffer.id);
            break;
        case BufferType.Vbo:
            gl.GenBuffers(1, &buffer.id);
        case BufferType.Ibo:
            gl.GenBuffers(1, &buffer.id);
        case BufferType.Ubo:
            gl.GenBuffers(1, &buffer.id);
        case:
            panic("Unimplemented");
    }

    fmt.print("Done");
    return { error = BufferError.None, opt = utils.some(buffer) };
}

destroy_buffer :: proc (
    buffer_type:    types.BufferType,
    id:             u32,
    indent:         string = "  ") -> types.BufferError {
    using types;
    fmt.printf("\n[INFO]:{}| Destroying buffer of type '{}' ('') ... ", indent, buffer_type, id);

    id_ptr := id;
    gl.DeleteBuffers(1, &id_ptr);

    fmt.print("Done");
    return BufferError.None;
}

// TODO: Clear out buffer data, but keep capacity intact in case the space is reused later.
reset_buffer :: proc (buffer: ^types.Buffer, indent: string = "  ") {
    panic("Unimplemented");
}

prepare_buffer :: proc (
    buffer:         ^types.Buffer,
    opt_data:       types.Option([]u8) = nil,
    indent:         string = "  ") -> types.BufferError {
    using types;

    switch buffer.type {
        case BufferType.Framebuffer:
            assert(len(buffer.attachments_opt) > 1, "Failed to prepare framebuffer {}: No attachments found. Did you forget to call 'create_framebuffer_attachments(...)'?");

            gl.BindFramebuffer(gl.FRAMEBUFFER, buffer.id);
            gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, buffer.attachments_opt[0], 0);
            gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.TEXTURE_2D, buffer.attachments_opt[1], 0);
            status := gl.CheckFramebufferStatus(gl.FRAMEBUFFER);

            if status != gl.FRAMEBUFFER_COMPLETE {
                return types.BufferError.InvalidAttachments;
            }
            break;
        case BufferType.Vao:
            gl.BindVertexArray(buffer.id);
            break;
        case BufferType.Vbo:
            gl.BindBuffer(gl.ARRAY_BUFFER, buffer.id);
            gl.BufferData(gl.ARRAY_BUFFER, int(buffer.capacity), raw_data(utils.unwrap_or(opt_data, nil)), gl.DYNAMIC_DRAW);
            break;
        case BufferType.Ibo:
            gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, buffer.id);
            gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, int(buffer.capacity), raw_data(utils.unwrap_or(opt_data, nil)), gl.DYNAMIC_DRAW);
            break;
        case BufferType.Ubo:
            gl.BindBuffer(gl.UNIFORM_BUFFER, buffer.id);
            gl.BufferData(gl.UNIFORM_BUFFER, int(buffer.capacity), raw_data(utils.unwrap_or(opt_data, nil)), gl.DYNAMIC_DRAW);
            break;
        case:
            panic("Unimplemented");
    }

    hasError := restore_last_buffer_state(buffer);
    if hasError {
        return BufferError.BufferNotFound;
    }

    return BufferError.None;
}

grow_buffer :: proc (
    buffer:     ^types.Buffer,
    size_bytes: u64,
    indent:     string = "  ") -> types.BufferError {
    using types;


    fmt.printfln("[INFO]:{}| Growing buffer '{}' ({}) from {} bytes to {} ... ", indent, buffer.id, buffer.type, buffer.capacity,
        buffer.capacity + size_bytes);

    buffer.capacity += size_bytes;
    fmt.printfln("[INFO]:{}--- Done", indent);
    return BufferError.None;
}

shrink_buffer :: proc (
    buffer:     ^types.Buffer,
    size_bytes: u64,
    indent:     string = "  ") -> types.BufferError {
    using types;

    fmt.printf("\n[INFO]:{}| Shrinking buffer '{}' ({}) from {} bytes to {}... ", indent, buffer.id, buffer.type, buffer.capacity,
        buffer.capacity - size_bytes);

    if buffer.capacity - size_bytes < 0 {
        fmt.printf("\n[ERR]:{}--- Cannot shrink buffer: Shrink size ({}) is bigger than total capacity ({})", indent,
            size_bytes, buffer.capacity);
        return BufferError.InvalidSize;
    }

    buffer.capacity -= size_bytes;
    fmt.printfln("[INFO]:{}--- Done", indent);
    return BufferError.None;
}

migrate_buffer :: proc (
    buffer:             ^types.Buffer,
    new_size_bytes:     u64,
    from_where_bytes:   types.Option(u64) = nil,
    indent:             string = "  ") -> types.Result(types.Buffer) {
    using types;

    fmt.printfln("[INFO]:{}| Migrating buffer {} ({}) into a new buffer", indent, buffer.id, buffer.type);

    if new_size_bytes == buffer.capacity {
        fmt.printfln("[ERR]:{}--- Cannot migrate buffer {}: Original buffer size is the same as new one, skipping migration",
            indent, buffer.id);
        return { opt = utils.none(Buffer), error = BufferError.InvalidSize };
    }

    new_indent := strings.concatenate({indent, "  "});
    defer delete_string(new_indent);

    destination_buffer_result := create_buffer(buffer.type, new_size_bytes, new_indent);
    if destination_buffer_result.error != BufferError.None {
        return { opt = utils.none(Buffer), error = destination_buffer_result.error };
    }

    destination_buffer := utils.unwrap(destination_buffer_result.opt);

    gl.BindBuffer(gl.COPY_READ_BUFFER, buffer.id);
    gl.BindBuffer(gl.COPY_WRITE_BUFFER, destination_buffer.id);
    gl.CopyBufferSubData(gl.COPY_READ_BUFFER, gl.COPY_WRITE_BUFFER, int(utils.unwrap_or(from_where_bytes, 0)), 0, int(buffer.length));

    fmt.printfln("[INFO]:{}--- Done", indent);
    return { opt = destination_buffer_result.opt, error = BufferError.None };
}

push_data :: proc (
    buffer:           ^types.Buffer,
    data:             []byte,
    from_where_bytes: types.Option(u64) = nil,
    indent:           string = "  ") -> types.BufferError {
    using types;

    size_bytes       := u64(len(data));
    fmt.printfln("[INFO]:{}| Appending data ({}) of {} bytes into buffer {} at {}/{} ... ", indent, data, size_bytes, buffer.id,
        from_where_bytes, buffer.capacity);

    if buffer.length + size_bytes > buffer.capacity {
        fmt.printfln("[WARN]:{}--- Data too big ({}) for buffer's capacity ({}), growing it ...", indent, size_bytes, buffer.capacity);
        if err := grow_buffer(buffer, size_bytes); err != BufferError.None {
            return err;
        }
    }

    gl.BindBuffer(_into_gl_type(buffer.type), buffer.id);
    gl.BufferSubData(_into_gl_type(buffer.type), int(utils.unwrap_or(from_where_bytes, buffer.length)), int(size_bytes), raw_data(data));
    restore_last_buffer_state(buffer);

    buffer.length += size_bytes;
    buffer.count  += size_bytes / buffer.size;
    fmt.printfln("[INFO]:{}--- Done", indent);
    return BufferError.None;
}

pop_data :: proc (
    buffer:           ^types.Buffer,
    size_bytes:       u64,
    from_where_bytes: types.Option(u64) = nil,
    indent:           string = "  ") -> types.Result([]byte) {
    using types;

    fmt.printfln("[INFO]:{}| Popping data of {} bytes from buffer {} at {}/{} ... ", indent, size_bytes, buffer.id,
    buffer.length, buffer.capacity);

    if buffer.length - size_bytes < 0 {
        fmt.printfln("[ERR]:{}--- Cannot pop data from buffer: Bytes requested ({}) would underflow the buffer's capacity ({}). ",
            indent, size_bytes, buffer.capacity);
        return { opt = utils.none([]byte), error = BufferError.InvalidSize };
    }

    from_where := utils.unwrap_or(from_where_bytes, buffer.length);
    get_data : []byte = {};

    gl.BindBuffer(_into_gl_type(buffer.type), buffer.id);
    gl.BufferSubData(_into_gl_type(buffer.type), int(from_where), int(size_bytes), nil);
    gl.GetBufferSubData(_into_gl_type(buffer.type), int(from_where), int(size_bytes), &get_data);
    restore_last_buffer_state(buffer);

    buffer.length -= size_bytes;
    buffer.count  -= size_bytes / buffer.size;
    fmt.printfln("[INFO]:{}--- Done", indent);
    return { opt = utils.some(get_data), error = BufferError.None };
}

// TODO: Pack node styling and properties into appropriate uniforms and vertex data to pass to shader later on.
serialize_nodes :: proc (root: ^types.Node, indent: string = "  ") -> types.Result([]byte) {
    panic("Unimplemented");
}

get_last_program :: proc () -> types.Result(u32) {
    program_id: i32 = 0;

    gl.GetIntegeri_v(gl.CURRENT_PROGRAM, 0, &program_id);
    if program_id <= 0 {
        return { error = types.ProgramError.ProgramNotFound, opt = utils.none(u32) };
    }

    return { error = types.ProgramError.None, opt = utils.some(u32(program_id)) };
}

get_last_vao :: proc () -> types.Result(u32) {
    vao_id: i32 = 0;

    gl.GetIntegerv(gl.VERTEX_ARRAY_BINDING, &vao_id);
    if vao_id <= 0 {
        return { error = types.BufferError.BufferNotFound, opt = utils.none(u32) };
    }

    return { error = types.BufferError.None, opt = utils.some(u32(vao_id)) };
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

get_last_ubo :: proc() -> types.Result(u32) {
    panic("Unimplemented");
}

get_last_framebuffer :: proc() -> types.Result(u32) {
    panic("Unimplemented");
}

restore_last_buffer_state :: proc(current_buffer: ^types.Buffer) -> bool {
    using types;

    switch current_buffer.type {
        case BufferType.Vao:
            last_vao := get_last_vao();
            if vao_id := utils.unwrap(last_vao.opt); utils.is_some(last_vao.opt) {
                gl.BindVertexArray(vao_id);
            }
            return last_vao.error != BufferError.None;
        case BufferType.Vbo:
            last_vbo := get_last_vbo();
            if vbo_id := utils.unwrap(last_vbo.opt); utils.is_some(last_vbo.opt) {
                gl.BindBuffer(gl.ARRAY_BUFFER, vbo_id);
            }
            return last_vbo.error != BufferError.None;
        case BufferType.Ibo:
            last_ibo := get_last_ibo();
            if ibo_id := utils.unwrap(last_ibo.opt); utils.is_some(last_ibo.opt) {
                gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ibo_id);
            }
            return last_ibo.error != BufferError.None;
        case BufferType.Ubo:
            last_ubo := get_last_ubo();
            if ubo_id := utils.unwrap(last_ubo.opt); utils.is_some(last_ubo.opt) {
                gl.BindBuffer(gl.UNIFORM_BUFFER, ubo_id);
            }
            return last_ubo.error != BufferError.None;
        case BufferType.Framebuffer:
            last_framebuffer := get_last_framebuffer();
            if framebuffer_id := utils.unwrap(last_framebuffer.opt); utils.is_some(last_framebuffer.opt) {
                gl.BindFramebuffer(gl.FRAMEBUFFER, framebuffer_id);
            }
            return last_framebuffer.error != BufferError.None;
        case:
            panic("Unimplemented");
    }

    return false;
}

_into_gl_type :: proc (buffer_type: types.BufferType) -> u32 {
    using types;

    switch buffer_type {
        case BufferType.Framebuffer:    return gl.FRAMEBUFFER;
        case BufferType.Vbo:            return gl.ARRAY_BUFFER;
        case BufferType.Vao:            return gl.VERTEX_ARRAY;
        case BufferType.Ibo:            return gl.ELEMENT_ARRAY_BUFFER;
        case BufferType.Ubo:            return gl.UNIFORM_BUFFER;
        case:                           panic("Unimplemented");
    }
}

