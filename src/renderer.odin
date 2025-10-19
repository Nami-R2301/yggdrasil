#+feature dynamic-literals
package ygg;

import fmt   "core:fmt";
import queue "core:container/queue";
import gl    "vendor:OpenGL";
import glfw  "vendor:glfw";
import libc  "core:c/libc";

import types "types";
import utils "utils";

////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////// CORE //////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////

create_renderer :: proc (
    type:     types.RendererType = types.RendererType.OpenGL,
    indent:   string = "  ") -> types.Result(types.Renderer) {
    using types;

    fmt.printfln("[INFO]:{}| Creating renderer ... ", indent);

    if type == RendererType.Vulkan {
        fmt.eprintfln("[ERR]:{}--- Error creating renderer: Vulkan API not supported yet! Please use OpenGL for now ...",
        indent);
        return { error = RendererError.InvalidAPI, opt = utils.none(Renderer) };
    }

    // Load GL functions.
    gl.load_up_to(4, 3, glfw.gl_set_proc_address);
    fmt.printfln("[INFO]:{}  --- Loaded GL bindings up to 4.3", indent);

    // Enable async error handling for OpenGL calls.
    gl.Enable(gl.DEBUG_OUTPUT);
    gl.Enable(gl.DEBUG_OUTPUT_SYNCHRONOUS);
    gl.DebugMessageCallback(gl_asynchronous_error_callback, nil);
    gl.DebugMessageControl(gl.DONT_CARE, gl.DEBUG_TYPE_OTHER, gl.DONT_CARE, 0, nil, gl.FALSE);

    gl.Enable(gl.DEPTH_TEST);    // Use z-index to determine layer order
    gl.Enable(gl.SCISSOR_TEST);  // Create a bounding-box to prevent overflow
    gl.Enable(gl.STENCIL_TEST);  // Ability to round corners

    gl.Enable(gl.BLEND);
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

    buffer_vao, buffer_vbo, buffer_ibo := _create_initial_buffers();

    renderer : Renderer = {
        vao   = buffer_vao,
        vbo   = buffer_vbo,
        ibo   = buffer_ibo,
        state = RendererState.Initialized
    };

    vertex_error   := load_shader(filepath = "./res/main.vert", shader_type = ShaderType.Vertex);
    fragment_error := load_shader(filepath = "./res/main.frag", shader_type = ShaderType.Vertex);
    assert(vertex_error == ShaderError.None && fragment_error == ShaderError.None, "Error loading vertex and fragment shaders");

    fmt.printfln("[INFO]:{}--- Done", indent);
    return { error = RendererError.None, opt = utils.some(renderer) };
}

destroy_renderer :: proc (renderer_ptr: ^types.Renderer, indent: string = "  ") -> types.RendererError {
    using types;

    fmt.printf("[INFO]:{}| Destroying renderer ... ", indent);
    if renderer_ptr != nil {
        fmt.eprintfln("[ERR]:{}--- Error when finding buffer: No renderer found! Did you forget to first call 'create_renderer()'?",
        indent);
        return RendererError.InvalidRenderer;
    }

    queue.destroy(&renderer_ptr.node_queue);

    gl.DeleteProgram(renderer_ptr.program);
    gl.DeleteBuffers(1, &renderer_ptr.vbo.id);
    gl.DeleteBuffers(1, &renderer_ptr.vao.id);
    gl.DeleteBuffers(1, &renderer_ptr.ibo.id);
    gl.DeleteBuffers(1, ([^]u32)(raw_data(renderer_ptr.ubos)));

    delete_dynamic_array(renderer_ptr.ubos);
    delete_dynamic_array(renderer_ptr.textures);
    delete_dynamic_array(renderer_ptr.framebuffers);

    renderer_ptr.state = RendererState.Destroyed;
    fmt.print("Done");
    return RendererError.None;
}

@(private)
_create_initial_buffers :: proc () -> (types.Buffer, types.Buffer, types.Buffer) {
    using types;

    vao : u32 = 0;
    vbo : u32 = 0;
    ibo : u32 = 0;

    gl.GenVertexArrays(1, &vao);
    gl.GenBuffers(1, &vbo);
    gl.GenBuffers(1, &ibo);

    last_vao_bound : i32 = 0;
    last_vbo_bound : i32 = 0;

    gl.GetIntegerv(gl.VERTEX_ARRAY_BINDING, &last_vao_bound);
    gl.GetIntegerv(gl.ARRAY_BUFFER_BINDING, &last_vbo_bound);

    gl.BindVertexArray(vao);
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo);

    // i32 + vec3 + vec4 + vec2 + mat4
    stride: i32 = size_of(u32) + (3 * size_of(f32)) + (4 * size_of(f32)) + (2 * size_of(f32)) + 16 * size_of(f32);
    offset := 0;

    // vin_entity_id (int)
    gl.EnableVertexAttribArray(0);
    gl.VertexAttribIPointer(0, 1, gl.INT, stride, uintptr(0));
    gl.VertexAttribDivisor(0, 1);  // Flat
    offset = size_of(i32);

    // vin_position (vec3)
    gl.EnableVertexAttribArray(1);
    gl.VertexAttribPointer(1,  3, gl.FLOAT, gl.FALSE, stride, uintptr(offset));
    offset += 3 * size_of(f32);

    // vin_color (vec4)
    gl.EnableVertexAttribArray(2);
    gl.VertexAttribPointer(2,  4, gl.FLOAT, gl.FALSE, stride, uintptr(offset));
    offset += 4 * size_of(f32);

    // Texture (vec2)
    gl.EnableVertexAttribArray(3);
    gl.VertexAttribPointer(3,  2, gl.FLOAT, gl.FALSE, stride, uintptr(offset));
    offset += 2 * size_of(f32);

    // Model Matrix (mat4)
    last_vertex_index: u32 = 3;
    for row in u32(0)..<4 {
        gl.EnableVertexAttribArray(row + last_vertex_index);
        gl.VertexAttribPointer(row + last_vertex_index,  4, gl.FLOAT, gl.FALSE, stride, uintptr(offset));
        offset += 4 * size_of(f32);
    }

    // Restore to previous state
    gl.BindVertexArray(u32(last_vao_bound));
    gl.BindBuffer(gl.ARRAY_BUFFER, u32(last_vbo_bound));

    buffer_vao := Buffer {
        id          = vao,
        type        = BufferType.vao,
        capacity    = 1,
        count       = 0,
        size        = 0
    };
    buffer_vbo := Buffer {
        id          = vbo,
        type        = BufferType.vbo,
        capacity    = 1_000_000,
        count       = 0,
        size        = 0
    };
    buffer_ibo := Buffer {
        id          = ibo,
        type        = BufferType.ibo,
        capacity    = 1_000_000,
        count       = 0,
        size        = 0
    };

    return buffer_vao, buffer_vbo, buffer_ibo;
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

    libc.printf("[OpenGL] | [%d] | [%s] -> %s", temp.code, temp.severity, temp.description);
}