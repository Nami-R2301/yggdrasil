package ygg;

import gl       "vendor:OpenGL";
import fmt      "core:fmt";
import mem      "core:mem";
import strings  "core:strings";
import runtime  "base:runtime";

import types "types";
import utils "utils"

C_VBO_SIZE_LIMIT : u64 = 10_000_000;

@(export, link_prefix="ygg_")
create_framebuffer :: proc "c" (
    fbo_width: u32,
    fbo_height: u32,
    indent: string = "  ") -> types.Buffer {
    context = runtime.default_context();

    fmt.printf("[INFO]:{}| Creating Framebuffer ... ", indent);
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

    buffer := types.Buffer {
        type = types.BufferType.Framebuffer,
        count = 1,
        attachments_opt = textures
    };
    gl.GenFramebuffers(1, &buffer.id);

    fmt.println("Done");
    return buffer;
}

@(export, link_prefix="ygg_")
create_buffer :: proc "c" (
    buffer_type:    types.BufferType,
    capacity:       u64 = 1_000_000,
    indent:         string = "  ") -> (types.Buffer, types.Error) {
    context = runtime.default_context();

    buffer := types.Buffer {
        id = 0,
        type = buffer_type,
        count = 0,
        length = 0,
        capacity = capacity,
    };

    fmt.printf("[INFO]:{}| Creating buffer of type '{}' and capacity of '{}' ... ", indent, buffer_type, capacity);

    if buffer.capacity > C_VBO_SIZE_LIMIT {
        fmt.eprintfln("[ERR]:{}--- Buffer capacity '{}' for ('{}') exceeds the maximum allowed bytes ({})", indent,
        buffer.capacity, buffer.id, C_VBO_SIZE_LIMIT);
        return { }, types.BufferError.ExceededMaxSize;
    }

    switch buffer.type {
    case types.BufferType.Vao:
        gl.GenVertexArrays(1, &buffer.id);
        break;
    case types.BufferType.Framebuffer:
        gl.GenFramebuffers(1, &buffer.id);
        break;
    case types.BufferType.Vbo:
        gl.GenBuffers(1, &buffer.id);
    case:
        panic("Unimplemented");
    }

    fmt.println("Done");
    return buffer, types.BufferError.None;
}

@(export, link_prefix="ygg_")
destroy_buffer :: proc "c" (buffer: ^types.Buffer, indent: string = "  ") -> types.BufferError {
    context = runtime.default_context();

    fmt.printf("\n[INFO]:{}| Destroying buffer of type '{}' ('') ... ", indent, utils.into_str(buffer));

    gl.DeleteBuffers(1, &buffer.id);

    fmt.print("Done");
    return types.BufferError.None;
}

// TODO: Check if it is uploaded to GPU and memset it on there as well
@(export, link_prefix="ygg_")
reset_buffer :: proc "c" (buffer: ^types.Buffer, indent: string = "  ") -> types.BufferError {
    context = runtime.default_context();

    fmt.printf("\n[INFO]:{}| Resetting buffer ({}) ... ", indent, utils.into_str(buffer));

    buffer.length = 0;
    buffer.count = 0;
    fmt.printfln("[INFO]:{}--- Done", indent);
    return types.BufferError.None;
}

@(export, link_prefix="ygg_")
prepare_buffer :: proc "c" (
    buffer:         ^types.Buffer,
    opt_data:       types.Data = { },
    indent:         string = "  ") -> types.BufferError {
    context = runtime.default_context();

    fmt.printf("[INFO]:{}| Preparing {} ... ", indent, buffer.type);

    switch buffer.type {
    case types.BufferType.Framebuffer:
        assert(len(buffer.attachments_opt) > 1, "Failed to prepare framebuffer {}: No attachments found. Did you forget to call 'create_framebuffer_attachments(...)'?");

        gl.BindFramebuffer(gl.FRAMEBUFFER, buffer.id);
        gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, buffer.attachments_opt[0], 0);
        gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.TEXTURE_2D, buffer.attachments_opt[1], 0);
        status := gl.CheckFramebufferStatus(gl.FRAMEBUFFER);

        if status != gl.FRAMEBUFFER_COMPLETE {
            return types.BufferError.InvalidAttachments;
        }
        break;
    case types.BufferType.Vao:
        gl.BindVertexArray(buffer.id);
        break;
    case types.BufferType.Vbo:
        gl.BindBuffer(gl.ARRAY_BUFFER, buffer.id);
        gl.BufferData(gl.ARRAY_BUFFER, int(buffer.capacity), nil, gl.DYNAMIC_DRAW);
        break;
    case:
        panic("Unimplemented");
    }

    if opt_data.ptr != nil {
        new_indent := strings.concatenate({ indent, "  " }, context.temp_allocator);

        if err := push_data(context, buffer, opt_data, indent = new_indent); err != types.BufferError.None {
            restore_last_buffer_state(buffer);
            return err;
        }
    }

    restore_last_buffer_state(buffer);


    fmt.println("Done");
    return types.BufferError.None;
}

@(export, link_prefix="ygg_")
grow_buffer :: proc "c" (
    ctx:        runtime.Context,
    buffer:     ^types.Buffer,
    size_bytes: u64,
    indent:     string = "  ") -> types.BufferError {
    context = ctx;

    fmt.printf("[INFO]:{}| Growing buffer '{}' ({}) from {} bytes to {} ... ", indent, buffer.id, buffer.type, buffer.capacity,
    buffer.capacity + size_bytes);

    buffer.capacity += size_bytes;
    fmt.printfln("Done");
    return types.BufferError.None;
}

@(export, link_prefix="ygg_")
shrink_buffer :: proc "c" (
    ctx:        runtime.Context,
    buffer:     ^types.Buffer,
    size_bytes: u64,
    indent:     string = "  ") -> types.BufferError {
    context = ctx;

    fmt.printf("\n[INFO]:{}| Shrinking buffer '{}' ({}) from {} bytes to {}... ", indent, buffer.id, buffer.type, buffer.capacity,
    buffer.capacity - size_bytes);

    if buffer.capacity - size_bytes < 0 {
        fmt.printf("\n[ERR]:{}--- Cannot shrink buffer: Shrink size ({}) is bigger than total capacity ({})", indent,
        size_bytes, buffer.capacity);
        return types.BufferError.InvalidSize;
    }

    buffer.capacity -= size_bytes;
    fmt.printfln("[INFO]:{}--- Done", indent);
    return types.BufferError.None;
}

@(export, link_prefix="ygg_")
migrate_buffer :: proc "c" (
    ctx:                runtime.Context,
    buffer:             ^types.Buffer,
    new_size_bytes:     u64,
    from_where_bytes:   Maybe(u64) = 0,
    allocator:          mem.Allocator,
    indent:             string = "  ") -> (types.Buffer, types.Error) {
    context = ctx;

    fmt.printfln("[INFO]:{}| Migrating buffer {} ({}) into a new buffer ... ", indent, buffer.id, buffer.type);

    if new_size_bytes == buffer.capacity {
        fmt.printfln("[ERR]:{}--- Cannot migrate buffer {}: Original buffer size is the same as new one, skipping migration",
        indent, buffer.id);
        return { }, types.BufferError.InvalidSize;
    }

    new_indent := strings.concatenate({ indent, "  " }, allocator);
    dest_buffer, error := create_buffer(buffer.type, new_size_bytes, new_indent);
    if error != types.BufferError.None {
        return { }, error;
    }

    gl.BindBuffer(gl.COPY_READ_BUFFER, buffer.id);
    gl.BindBuffer(gl.COPY_WRITE_BUFFER, dest_buffer.id);
    gl.CopyBufferSubData(gl.COPY_READ_BUFFER, gl.COPY_WRITE_BUFFER, int(utils.unwrap_or(from_where_bytes, 0)), 0, int(buffer.length));

    fmt.printfln("[INFO]:{}--- Done", indent);
    return dest_buffer, types.BufferError.None;
}

@(export, link_prefix="ygg_")
push_data :: proc "c" (
    ctx:              runtime.Context,
    buffer:           ^types.Buffer,
    data:             types.Data,
    from_where_bytes: Maybe(u64) = 0,
    indent:           string = "  ") -> types.BufferError {
    context = ctx;

    original_size := buffer.capacity;
    from_where := utils.unwrap_or(from_where_bytes, buffer.length);
    size_bytes := data.count * data.size;
    fmt.printf("[INFO]:{}| [{}] Appending data (count = {}, size = %2d) at {}/{} ... ", indent,
    buffer.type, data.count, data.size, from_where, original_size);

    if from_where + size_bytes > original_size {
        fmt.printfln("\n[WARN]:{}--- Data too big ({}) for buffer's capacity ({}), growing it ...", indent, size_bytes, buffer.capacity);
        new_indent, err := strings.concatenate({indent, "  "}, context.temp_allocator);
        assert(err == mem.Allocator_Error.None, "[ERR]:\tCannot push data: Out of memory (buy more ram)");

        if err := grow_buffer(context, buffer, size_bytes, new_indent); err != types.BufferError.None {
            return err;
        }
    }

    gl.BindBuffer(_into_gl_type(buffer.type), buffer.id);
    gl.BufferSubData(_into_gl_type(buffer.type), int(from_where), int(size_bytes), data.ptr);
    restore_last_buffer_state(buffer);

    buffer.length += size_bytes;
    buffer.count += data.count;

    if original_size != buffer.capacity {
        fmt.printfln("[INFO]:{}--- Done ({}/{})", indent, buffer.length, buffer.capacity);
    } else {
        fmt.printfln("Done ({}/{})", buffer.length, buffer.capacity);
    }
    return types.BufferError.None;
}

@(export, link_prefix="ygg_")
pop_data :: proc "c" (
    ctx:              runtime.Context,
    buffer:           ^types.Buffer,
    size_bytes:       u64,
    count:            u64,
    from_where_bytes: Maybe(u64) = 0,
    indent:           string = "  ") -> (types.Data, types.Error) {
    context = ctx;

    from_where := utils.unwrap_or(from_where_bytes, buffer.length);
    fmt.printf("[INFO]:{}| [{}] | Popping {} bytes at {}/{} ... ", indent, buffer.type, size_bytes, from_where, buffer.capacity);

    if buffer.length - size_bytes < 0 {
        fmt.printfln("\n[ERR]:{}--- Cannot pop data from buffer: Bytes requested ({}) would underflow the buffer's capacity ({}). ",
        indent, size_bytes, buffer.capacity);
        return { }, types.BufferError.InvalidSize;
    }

    get_data : rawptr;

    gl.BindBuffer(_into_gl_type(buffer.type), buffer.id);
    gl.BufferSubData(_into_gl_type(buffer.type), int(from_where), int(size_bytes * count), nil);
    gl.GetBufferSubData(_into_gl_type(buffer.type), int(from_where), int(size_bytes * count), get_data);
    restore_last_buffer_state(buffer);

    buffer.length -= size_bytes;
    buffer.count -= count;
    fmt.println("Done");
    return types.Data{ ptr = get_data, count = count, size = size_bytes }, types.BufferError.None;
}

@(export, link_prefix="ygg_")
push_text :: proc "c" (
    ctx:    ^types.Context,
    text:   ^types.Node,
    indent: string = "  ") -> types.Error {
    context = ctx._context;
    if ctx == nil || ctx.renderer == nil {
        fmt.eprintfln("[ERR]:{} --- Cannot push text: No renderer found or is nil. Did you forget to call 'create_renderer' ?",
        indent);
        return types.BufferError.InvalidRenderer;
    }

    data: ^types.Data = cast(^types.Data)text.user_data;
    if data == nil {
        fmt.printfln("[WARN]:{}--- Cannot push text: No data found in text node, skipping ...");
        return types.BufferError.InvalidPtr;
    }

    if err := push_data(context, &ctx.renderer.pipeline.vbo, data^, indent = indent); err != nil {
        fmt.eprintfln("[ERR]:{} --- Cannot push text: {}", indent, err);
        return err;
    }

    // TODO: Pack node styling and properties into appropriate uniforms and vertex data to pass to shader later on.

    return types.BufferError.None;
}

@(export, link_prefix="ygg_")
push_box :: proc "c" (
    ctx:    ^types.Context,
    box:    ^types.Node,
    indent: string = "  ") -> types.Error {
    context = ctx._context;
    if ctx == nil || ctx.renderer == nil {
        fmt.eprintfln("[ERR]:{} --- Cannot push box: No renderer found or is nil. Did you forget to call 'create_renderer' ?",
            indent);
        return types.BufferError.InvalidRenderer;
    }

    data: ^types.Data = cast(^types.Data)box.user_data;
    if data == nil {
        fmt.printfln("[WARN]:{}--- Cannot push text: No data found in text node, skipping ...");
        return types.BufferError.InvalidPtr;
    }

    if err := push_data(context, &ctx.renderer.pipeline.vbo, data^, indent = indent); err != nil {
        fmt.eprintfln("[ERR]:{} --- Cannot push text: {}", indent, err);
        return err;
    }

    // TODO: Pack node styling and properties into appropriate uniforms and vertex data to pass to shader later on.

    return types.BufferError.None;
}

@(export, link_prefix="ygg_")
push_img :: proc "c" (ctx: ^types.Context, img: ^types.Node, indent: string = "  ") -> types.Error {
    panic_contextless("Unimplemented");
}

@(export, link_prefix="ygg_")
push_node :: proc "c" (ctx: ^types.Context, custom_node: ^types.Node, indent: string = "  ") -> types.Error {
    panic_contextless("Unimplemented");
}

@(export, link_prefix="ygg_")
restore_last_buffer_state :: proc "c" (current_buffer: ^types.Buffer) {
    switch current_buffer.type {
    case types.BufferType.Vao:
        last_vao, exists := get_last_vao();
        if exists {
            gl.BindVertexArray(last_vao);
        }
    case types.BufferType.Vbo:
        last_vbo, exists := get_last_vbo();
        if exists {
            gl.BindBuffer(gl.ARRAY_BUFFER, last_vbo);
        }
    case types.BufferType.Framebuffer:
        gl.BindFramebuffer(gl.FRAMEBUFFER, 0);
    case:
        panic_contextless("Unimplemented");
    }
}

@(export, link_prefix="ygg_")
get_last_vao :: proc "c" () -> (u32, bool) {
    vao_id : i32 = 0;

    gl.GetIntegerv(gl.VERTEX_ARRAY_BINDING, &vao_id);
    if vao_id <= 0 {
        return 0, false;
    }

    return u32(vao_id), true;
}

@(export, link_prefix="ygg_")
get_last_vbo :: proc "c" () -> (u32, bool) {
    vbo_id : i32 = 0;

    gl.GetIntegerv(gl.ARRAY_BUFFER_BINDING, &vbo_id);
    if vbo_id <= 0 {
        return 0, false;
    }

    return u32(vbo_id), true;
}

@(export, link_prefix="ygg_")
get_last_texture :: proc "c" () -> (u32, bool) {
    texture_id: i32 = 0;

    gl.GetIntegerv(gl.TEXTURE_BINDING_2D, &texture_id);
    if texture_id <= 0 {
        return 0, false;
    }

    return u32(texture_id), true;
}

@(export, link_prefix="ygg_")
_into_gl_type :: proc "c" (buffer_type: types.BufferType) -> u32 {
    switch buffer_type {
    case types.BufferType.Framebuffer:    return gl.FRAMEBUFFER;
    case types.BufferType.Vbo:            return gl.ARRAY_BUFFER;
    case types.BufferType.Vao:            return gl.VERTEX_ARRAY;
    case: panic_contextless("Unimplemented");
    }
}
