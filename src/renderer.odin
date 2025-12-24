#+feature dynamic-literals
package ygg;

import fmt     "core:fmt";
import queue   "core:container/queue";
import gl      "vendor:OpenGL";
import glfw    "vendor:glfw";
import runtime "base:runtime";
import linalg  "core:math/linalg";

import types   "types";

create_renderer :: proc (window: ^types.Window, indent: string = "  ") -> (types.Renderer, types.Error) {
    using types;

    assert(window != nil, "[ERR]:\tError creating renderer: Window is nil!");

    fmt.printfln("[INFO]:{}| Creating renderer ... ", indent);

    // Load GL functions.
    gl.load_up_to(4, 3, glfw.gl_set_proc_address);
    fmt.printfln("[INFO]:{}  --- Loaded GL bindings up to 4.3", indent);

    // Enable async error handling for OpenGL calls.
    gl.Enable(gl.DEBUG_OUTPUT);
    gl.Enable(gl.DEBUG_OUTPUT_SYNCHRONOUS);
    gl.DebugMessageCallback(gl_asynchronous_error_callback, context.user_ptr);
    gl.DebugMessageControl(gl.DONT_CARE, gl.DEBUG_TYPE_OTHER, gl.DONT_CARE, 0, nil, gl.FALSE);

    // Init buffers
    buffer_vao, buffer_vbo := _create_initial_buffers();

    // Create UI Layer
    fbo        := create_framebuffer(window.dimensions[0], window.dimensions[1]);
    fbo_error  := prepare_buffer(&fbo);
    assert(fbo_error == BufferError.None, "[ERR]:\tError preparing Framebuffer");

    renderer : Renderer = {
        vao = buffer_vao,
        vbo = buffer_vbo,
        state = RendererState.Initialized
    };

    // Init basic shader
    program_id, error   := load_shaders(filepaths = {"./res/main.vert", "./res/main.frag"});
    if error != ShaderError.None {
        fmt.println("[ERR]:{}--- Error loading vertex and fragment shaders");
    } else {
        fmt.printfln("[INFO]:{}--- Done", indent);
    }

    renderer.program = program_id;
    return renderer, RendererError.None;
}

destroy_renderer :: proc (renderer_ptr: ^types.Renderer, indent: string = "  ") -> types.RendererError {
    using types;

    fmt.printf("[INFO]:{}| Destroying renderer ... ", indent);
    if renderer_ptr == nil {
        fmt.eprintfln("[ERR]:{}--- Error when finding buffer: No renderer found! Did you forget to first call 'create_renderer()'?",
        indent);
        return RendererError.InvalidRenderer;
    }

    if queue.len(renderer_ptr.node_queue) > 0 {
        queue.destroy(&renderer_ptr.node_queue);
    }

    gl.DeleteProgram(renderer_ptr.program);
    gl.DeleteBuffers(1, &renderer_ptr.vao.id);
    gl.DeleteBuffers(1, &renderer_ptr.vbo.id);

    if renderer_ptr.framebuffer.id != 0 {
        gl.DeleteBuffers(1, &renderer_ptr.framebuffer.id);
        gl.DeleteTextures(2, &renderer_ptr.framebuffer.attachments_opt[0]);
    }

    for &texture in renderer_ptr.textures {
        gl.DeleteTextures(1, &texture.id);
    }
    delete(renderer_ptr.textures);

    renderer_ptr.state = RendererState.Destroyed;
    fmt.println("Done");
    return RendererError.None;
}

@(private)
update_viewport_and_camera :: proc "contextless" (width, height: i32, indent: string = "  ") -> types.Error {
    using types;

    gl.Viewport(0, 0, width, height)

    program_id, exists := get_last_program();
    if !exists {
        return ProgramError.ProgramNotFound;
    }

    gl.UseProgram(program_id);

    loc_view := gl.GetUniformLocation(program_id, "u_view")
    if loc_view != -1 {
    // We swap Bottom (height) and Top (0) to move the origin to Top-Left
        projection := linalg.matrix_ortho3d(
        0,              // Left
        f32(width),     // Right
        f32(height),    // Bottom
        0,              // Top
        -1.0,           // Near
        1.0             // Far
        );

        gl.UniformMatrix4fv(loc_view, 1, false, &projection[0, 0])
    }

    return ProgramError.None;
}

@(private)
gl_asynchronous_error_callback :: proc "c" (
    error_code:     u32,
    type:           u32,
    id:             u32,
    severity:       u32,
    length:         i32,
    error_message:  cstring,
    userParam:      rawptr) {
    if error_code == gl.NO_ERROR {
        return;
    }
    context = runtime.default_context();

    temp: types.AsyncErrorMessage = {
        code = error_code,
        description = error_message
    };

    switch type {
        case gl.DEBUG_TYPE_ERROR:               temp.type = "Error";
        case gl.DEBUG_TYPE_DEPRECATED_BEHAVIOR: temp.type = "Deprecated Behaviour";
        case gl.DEBUG_TYPE_UNDEFINED_BEHAVIOR:  temp.type = "Undefined Behaviour";
        case gl.DEBUG_TYPE_PORTABILITY:         temp.type = "Portability";
        case gl.DEBUG_TYPE_PERFORMANCE:         temp.type = "Performance";
        case gl.DEBUG_TYPE_MARKER:              temp.type = "Marker";
        case gl.DEBUG_TYPE_PUSH_GROUP:          temp.type = "Push Group";
        case gl.DEBUG_TYPE_POP_GROUP:           temp.type = "Pop Group";
        case gl.DEBUG_TYPE_OTHER:               temp.type = "Other";
        case:                                   temp.type = "Unknown";
    }

    // Note: Replace return statements for both low and notification severity levels for thorough debugging.
    switch severity {
        case gl.DEBUG_SEVERITY_HIGH:            temp.severity = "Fatal (High)";
        case gl.DEBUG_SEVERITY_MEDIUM:          temp.severity = "Warn (performance)";
        case gl.DEBUG_SEVERITY_LOW:             temp.severity = "Warn (low)";
        case gl.DEBUG_SEVERITY_NOTIFICATION:    temp.severity = "Warn (info)";
        case:                                   temp.severity = "Warn (Unknown)";
    }

    fmt.eprintfln("[ERR]:   [OpenGL] [{}] | [{}] -> {}", error_code, temp.severity, temp.description);
}

@(private)
_create_initial_buffers :: proc "contextless" () -> (types.Buffer, types.Buffer) {
    using types;

    vao : u32 = 0;
    vbo : u32 = 0;

    gl.GenVertexArrays(1, &vao);
    gl.GenBuffers(1, &vbo);

    last_vao_bound : i32 = 0;
    last_vbo_bound : i32 = 0;

    gl.GetIntegerv(gl.VERTEX_ARRAY_BINDING, &last_vao_bound);
    gl.GetIntegerv(gl.ARRAY_BUFFER_BINDING, &last_vbo_bound);

    gl.BindVertexArray(vao);
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo);

    // i32 + vec3 + vec4 + vec2
    stride: i32 = size_of(i32) + (3 * size_of(f32)) + (4 * size_of(f32)) + (2 * size_of(f32));
    offset := 0;

    // vin_entity_id
    gl.EnableVertexAttribArray(0);
    gl.VertexAttribIPointer(0, 1, gl.INT, stride, uintptr(0));
    gl.VertexAttribDivisor(0, 1);  // Flat
    offset = size_of(i32);

    // vin_position
    gl.EnableVertexAttribArray(1);
    gl.VertexAttribPointer(1,  3, gl.FLOAT, gl.FALSE, stride, uintptr(offset));
    offset += 3 * size_of(f32);

    // vin_color
    gl.EnableVertexAttribArray(2);
    gl.VertexAttribPointer(2,  4, gl.FLOAT, gl.FALSE, stride, uintptr(offset));
    offset += 4 * size_of(f32);

    // vin_tex_coords
    gl.EnableVertexAttribArray(3);
    gl.VertexAttribPointer(3,  2, gl.FLOAT, gl.FALSE, stride, uintptr(offset));

    // Restore to previous state
    gl.BindVertexArray(u32(last_vao_bound));
    gl.BindBuffer(gl.ARRAY_BUFFER, u32(last_vbo_bound));

    buffer_vao := Buffer {
        id          = vao,
        type        = BufferType.Vao,
        capacity    = 1,
        count       = 0,
    };
    buffer_vbo := Buffer {
        id          = vbo,
        type        = BufferType.Vbo,
        capacity    = 1_000_000,
        count       = 0,
    };

    return buffer_vao, buffer_vbo;
}