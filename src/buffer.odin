package ygg;

import gl       "vendor:OpenGL";
import fmt      "core:fmt";
import mem      "core:mem";
import strings  "core:strings";

import types "types";
import utils "utils"

C_VBO_SIZE_LIMIT : u64 = 10_000_000;

create_framebuffer :: proc(fbo_width: u32, fbo_height: u32, indent: string = "  ") -> types.Buffer {
    using types;

    fmt.printf("[INFO]:{}| Creating framebuffer ... ", indent);
    textures : [2]u32 = { 0, 0 };

    gl.GenTextures(2, &textures[0]);

    // Color
    gl.BindTexture(gl.TEXTURE_2D, textures[0]);

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_BORDER);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_BORDER);

    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, i32(fbo_width), i32(fbo_height), 0, gl.RGBA, gl.UNSIGNED_BYTE, nil);
    gl.BindTexture(gl.TEXTURE_2D, 0);

    // Depth
    gl.BindTexture(gl.TEXTURE_2D, textures[1]);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.DEPTH_COMPONENT, i32(fbo_width), i32(fbo_height), 0, gl.DEPTH_COMPONENT, gl.UNSIGNED_BYTE, nil);
    gl.BindTexture(gl.TEXTURE_2D, 0);

    buffer := Buffer {
        type = BufferType.Framebuffer,
        count = 1,
        attachments_opt = textures
    };
    gl.GenFramebuffers(1, &buffer.id);

    fmt.println("Done");
    return buffer;
}

create_buffer :: proc (
    buffer_type:    types.BufferType,
    capacity:       u64 = 1_000_000,
    indent:         string = "  ") -> (types.Buffer, types.Error) {
    using types;

    buffer := Buffer {
        id = 0,
        type = buffer_type,
        count = 0,
        length = 0,
        capacity = capacity,
    };

    fmt.printf("\n[INFO]:{}| Creating buffer of type '{}' and capacity of '{}' ... ", indent, buffer_type, capacity);

    if buffer.capacity > C_VBO_SIZE_LIMIT {
        fmt.eprintfln("[ERR]:{}--- Buffer capacity '{}' for ('{}') exceeds the maximum allowed bytes ({})", indent,
        buffer.capacity, buffer.id, C_VBO_SIZE_LIMIT);
        return { }, types.BufferError.ExceededMaxSize;
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
    case:
        panic("Unimplemented");
    }

    fmt.print("Done");
    return buffer, BufferError.None;
}

destroy_buffer :: proc (buffer: ^types.Buffer, indent: string = "  ") -> types.BufferError {
    using types;

    fmt.printf("\n[INFO]:{}| Destroying buffer of type '{}' ('') ... ", indent, utils.into_str(buffer));

    gl.DeleteBuffers(1, &buffer.id);

    fmt.print("Done");
    return BufferError.None;
}

// TODO: Check if it is uploaded to GPU and memset it on there as well
reset_buffer :: proc (buffer: ^types.Buffer, indent: string = "  ") -> types.BufferError {
    using types;

    fmt.printf("\n[INFO]:{}| Resetting buffer ({}) ... ", indent, utils.into_str(buffer));

    buffer.length = 0;
    buffer.count = 0;
    fmt.printfln("[INFO]:{}--- Done", indent);
    return BufferError.None;
}

prepare_buffer :: proc (
    buffer:         ^types.Buffer,
    opt_data:       types.Data = { },
    allocator:      mem.Allocator = context.allocator,
    indent:         string = "  ") -> types.BufferError {
    using types;

    inner_indent := strings.concatenate({ indent, "        " }, allocator);
    fmt.printfln("[INFO]:{}| Preparing buffer ({}) ... ", indent, utils.into_str(buffer, inner_indent));

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
        gl.BufferData(gl.ARRAY_BUFFER, int(buffer.capacity), nil, gl.DYNAMIC_DRAW);
        break;
    case:
        panic("Unimplemented");
    }

    if opt_data.ptr != nil {
        new_indent := strings.concatenate({ indent, "  " }, allocator);

        if err := push_data(buffer, opt_data, indent = new_indent); err != BufferError.None {
            restore_last_buffer_state(buffer);
            return err;
        }
    }

    restore_last_buffer_state(buffer);

    fmt.printfln("[INFO]:{}--- Done", indent);
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
    allocator:          mem.Allocator = context.allocator,
    indent:             string = "  ") -> (types.Buffer, types.Error) {
    using types;

    fmt.printfln("[INFO]:{}| Migrating buffer {} ({}) into a new buffer", indent, buffer.id, buffer.type);

    if new_size_bytes == buffer.capacity {
        fmt.printfln("[ERR]:{}--- Cannot migrate buffer {}: Original buffer size is the same as new one, skipping migration",
        indent, buffer.id);
        return { }, BufferError.InvalidSize;
    }

    new_indent := strings.concatenate({ indent, "  " }, allocator);
    dest_buffer, error := create_buffer(buffer.type, new_size_bytes, new_indent);
    if error != BufferError.None {
        return { }, error;
    }

    gl.BindBuffer(gl.COPY_READ_BUFFER, buffer.id);
    gl.BindBuffer(gl.COPY_WRITE_BUFFER, dest_buffer.id);
    gl.CopyBufferSubData(gl.COPY_READ_BUFFER, gl.COPY_WRITE_BUFFER, int(utils.unwrap_or(from_where_bytes, 0)), 0, int(buffer.length));

    fmt.printfln("[INFO]:{}--- Done", indent);
    return dest_buffer, BufferError.None;
}

push_data :: proc (
    buffer:           ^types.Buffer,
    data:             types.Data,
    from_where_bytes: types.Option(u64) = nil,
    indent:           string = "  ") -> types.BufferError {
    using types;

    from_where := utils.unwrap_or(from_where_bytes, buffer.length);
    size_bytes := data.count * data.size;
    fmt.printf("[INFO]:{}| [{}] Appending data (count = {}, size = %2d) at {}/{} ... ", indent,
    buffer.type, data.count, data.size, from_where, buffer.capacity);

    if buffer.length + size_bytes > buffer.capacity {
        fmt.printfln("\n[WARN]:{}--- Data too big ({}) for buffer's capacity ({}), growing it ...", indent, size_bytes, buffer.capacity);
        if err := grow_buffer(buffer, size_bytes); err != BufferError.None {
            return err;
        }
    }

    gl.BindBuffer(_into_gl_type(buffer.type), buffer.id);
    gl.BufferSubData(_into_gl_type(buffer.type), int(from_where), int(size_bytes), data.ptr);
    restore_last_buffer_state(buffer);

    buffer.length += size_bytes;
    buffer.count += data.count;
    fmt.printfln("Done ({}/{})", buffer.length, buffer.capacity);
    return BufferError.None;
}

pop_data :: proc (
    buffer:           ^types.Buffer,
    size_bytes:       u64,
    count:            u64,
    from_where_bytes: types.Option(u64) = nil,
    indent:           string = "  ") -> (types.Data, types.Error) {
    using types;

    from_where := utils.unwrap_or(from_where_bytes, buffer.length);
    fmt.printf("[INFO]:{}| [{}] | Popping {} bytes at {}/{} ... ", indent, buffer.type, size_bytes, from_where, buffer.capacity);

    if buffer.length - size_bytes < 0 {
        fmt.printfln("\n[ERR]:{}--- Cannot pop data from buffer: Bytes requested ({}) would underflow the buffer's capacity ({}). ",
        indent, size_bytes, buffer.capacity);
        return { }, BufferError.InvalidSize;
    }

    get_data : rawptr;

    gl.BindBuffer(_into_gl_type(buffer.type), buffer.id);
    gl.BufferSubData(_into_gl_type(buffer.type), int(from_where), int(size_bytes * count), nil);
    gl.GetBufferSubData(_into_gl_type(buffer.type), int(from_where), int(size_bytes * count), get_data);
    restore_last_buffer_state(buffer);

    buffer.length -= size_bytes;
    buffer.count -= count;
    fmt.println("Done");
    return Data{ ptr = get_data, count = count, size = size_bytes }, BufferError.None;
}

// TODO: Pack node styling and properties into appropriate uniforms and vertex data to pass to shader later on.
serialize_nodes :: proc (root: ^types.Node, indent: string = "  ") -> ([]byte, types.Error) {
    panic("Unimplemented");
}

restore_last_buffer_state :: proc "contextless" (current_buffer: ^types.Buffer) {
    using types;

    switch current_buffer.type {
    case BufferType.Vao:
        last_vao, exists := get_last_vao();
        if exists {
            gl.BindVertexArray(last_vao);
        }
    case BufferType.Vbo:
        last_vbo, exists := get_last_vbo();
        if exists {
            gl.BindBuffer(gl.ARRAY_BUFFER, last_vbo);
        }
    case BufferType.Framebuffer:
        gl.BindFramebuffer(gl.FRAMEBUFFER, 0);
    case:
        panic_contextless("Unimplemented");
    }
}

get_last_vao :: proc "contextless" () -> (u32, bool) {
    vao_id : i32 = 0;

    gl.GetIntegerv(gl.VERTEX_ARRAY_BINDING, &vao_id);
    if vao_id <= 0 {
        return 0, false;
    }

    return u32(vao_id), true;
}

get_last_vbo :: proc "contextless" () -> (u32, bool) {
    vbo_id : i32 = 0;

    gl.GetIntegerv(gl.ARRAY_BUFFER_BINDING, &vbo_id);
    if vbo_id <= 0 {
        return 0, false;
    }

    return u32(vbo_id), true;
}

get_last_texture :: proc "contextless" () -> (u32, bool) {
    texture_id: i32 = 0;

    gl.GetIntegerv(gl.TEXTURE_BINDING_2D, &texture_id);
    if texture_id <= 0 {
        return 0, false;
    }

    return u32(texture_id), true;
}

_into_gl_type :: proc "contextless" (buffer_type: types.BufferType) -> u32 {
    using types;

    switch buffer_type {
    case BufferType.Framebuffer:    return gl.FRAMEBUFFER;
    case BufferType.Vbo:            return gl.ARRAY_BUFFER;
    case BufferType.Vao:            return gl.VERTEX_ARRAY;
    case: panic_contextless("Unimplemented");
    }
}

