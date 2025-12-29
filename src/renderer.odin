#+feature dynamic-literals
package ygg;

import fmt     "core:fmt";
import queue   "core:container/queue";
import mem     "core:mem";
import linalg  "core:math/linalg";
import runtime "base:runtime";

import glfw    "vendor:glfw";
import gl      "vendor:OpenGL";

import types   "types";
import strings "core:strings";

// Core API to create and initialize an OpenGL renderer for displaying the UI nodes. Note that, we are technically using
// 3D space for z-indices, but everything else can be considered in 2D space. In order to make this renderer agnostic, all GL
// calls properly revert the GL states to what they were prior to any calls. Due to this nature, an additional
// framebuffer gets created and only that one gets swapped to keep all apps calling this library as a UI layer intact.
//
// @lifetime                        No heap memory footprint here. Only loading shaders require heap data, and that is
//                                  handled with the temp allocator. Does not require context's 'user_ptr' to be set.
//
// @param *window*:                 The window context (GLFW). Used to determine initial viewport sizes and OpenGL version.
// @param *indent*:                 The depth of the indent for all logs within this function.
//
// @return                          A renderer instance initialized. This function does return failure states, any
//                                  failure makes the program panic immediately.
create_renderer :: proc "c" (
    window:                 ^types.Window,
    indent:                 string = "  ") -> types.Renderer {
    using types;

    assert_contextless(window != nil, "[ERR]:\tError creating renderer: Window is nil!");
    context = runtime.default_context();

    desired_major_version := window.gl_version[0];
    desired_minor_version := window.gl_version[1];

    fmt.printfln("[INFO]:{}| Creating renderer (OpenGL {}.{} bindings) ... ",
        indent, desired_major_version, desired_minor_version);

    // Load GL functions.
    gl.load_up_to(int(desired_major_version), int(desired_minor_version), glfw.gl_set_proc_address);

    // Enable error handling for OpenGL calls.
    gl.Enable(gl.DEBUG_OUTPUT);
    if desired_major_version == 4 && desired_minor_version >= 3 || desired_major_version > 4 {
        gl.DebugMessageCallback(gl_asynchronous_error_callback, nil);
        gl.DebugMessageControl(gl.DONT_CARE, gl.DEBUG_TYPE_OTHER, gl.DONT_CARE, 0, nil, gl.FALSE);
    } else {
        gl.Enable(gl.DEBUG_OUTPUT_SYNCHRONOUS);
    }

    // Init buffers
    new_indent, err := strings.concatenate({indent, "  "}, context.temp_allocator);
    assert(err == mem.Allocator_Error.None, "[ERR]:\tCannot create renderer: Out of memory (buy more ram)");

    buffer_vao, buffer_vbo := create_initial_buffers(new_indent);
    vbo_error := prepare_buffer(&buffer_vbo, indent = new_indent);

    // Create UI Layer
    fbo        := create_framebuffer(window.dimensions[0], window.dimensions[1], indent = new_indent);
    fbo_error  := prepare_buffer(&fbo, indent = new_indent);
    assert(fbo_error == BufferError.None, "[ERR]:\tError preparing Framebuffer");

    renderer : Renderer = {
        pipeline = {
            vao = buffer_vao,
            vbo = buffer_vbo,
            framebuffer = fbo
        },
        state = RendererState.Initialized
    };

    // Init basic shader
    program_id, error   := load_shaders(filepaths = {"./res/main.vert", "./res/main.frag"});
    if error != ShaderError.None {
        fmt.println("[ERR]:{}--- Error loading vertex and fragment shaders");
    } else {
        fmt.printfln("[INFO]:{}--- Done", indent);
    }

    renderer.pipeline.program = program_id;
    return renderer;
}

// Core API to properly clean up the given renderer and destroy it. Destroys all GPU allocated data as well along with
// it. The renderer passed by pointer CANNOT be used after this function call succeeds.
//
// @lifetime                Static - no heap memory footprint. Does not require context's 'user_ptr' to be set.
//
// @param *renderer_ptr*:   Mutable - A renderer handle that contains a valid initialized OpenGL renderer instance.
// @param *indent*:         The depth of the indent for all logs within this function.
//
// @return                  On error, returns the renderer error that occured. Note that, this error will automatically
//                          be logged before returning and that in the event where the renderer did not have any GPU
//                          buffer data, some OpenGL errors may be logged in the console.
destroy_renderer :: proc "c" (renderer_ptr: ^types.Renderer, indent: string = "  ") -> types.RendererError {
    using types;

    context = runtime.default_context();

    fmt.printf("[INFO]:{}| Destroying renderer ... ", indent);
    if renderer_ptr == nil {
        fmt.eprintfln("[ERR]:{}--- Error when finding buffer: No renderer found! Did you forget to first call 'create_renderer()'?",
        indent);
        return RendererError.InvalidRenderer;
    }

    if queue.len(renderer_ptr.node_queue) > 0 {
        queue.destroy(&renderer_ptr.node_queue);
    }

    gl.DeleteProgram(renderer_ptr.pipeline.program);
    gl.DeleteBuffers(1, &renderer_ptr.pipeline.vao.id);
    gl.DeleteBuffers(1, &renderer_ptr.pipeline.vbo.id);

    if renderer_ptr.pipeline.framebuffer.id != 0 {
        gl.DeleteBuffers(1, &renderer_ptr.pipeline.framebuffer.id);
        gl.DeleteTextures(2, &renderer_ptr.pipeline.framebuffer.attachments_opt[0]);
    }

    for &texture in renderer_ptr.textures {
        gl.DeleteTextures(1, &texture.id);
    }
    delete(renderer_ptr.textures);

    renderer_ptr.state = RendererState.Destroyed;
    fmt.println("Done");
    return RendererError.None;
}

prepare_nodes :: proc "c" (
    ctx:            runtime.Context,
    nodes:          []^types.Node,
    indent:         string = "  ") -> types.Error {
    using types;

    context = ctx;
    ygg_ctx := cast(^Context)ctx.user_ptr;
    assert_contextless(ygg_ctx != nil, "[ERR]:\tCannot prepare nodes for render: Context is nil. Did you forget to set " +
    " context.user_ptr to 'ctx'?");

    fmt.printfln("[INFO]:{}| Batching nodes for rendering ... ", indent);

    assert_contextless(ygg_ctx.renderer != nil, "[ERR]:\tCannot prepare nodes for render: No renderer found. Did you " +
    "forget to call create_renderer(...) ?");

    for node in nodes {
        switch node.tag {
        case "text":
            if err := push_text(context, node, strings.concatenate({indent, "  "}, context.temp_allocator)); err != BufferError.None {
                fmt.eprintfln("[ERR]:{} --- Cannot prepare nodes for render: {}", indent, err);
                return err;
            }
        case "box":
            if err := push_box(context, node, strings.concatenate({indent, "  "}, context.temp_allocator)); err != BufferError.None {
                fmt.eprintfln("[ERR]:{} --- Cannot prepare nodes for render: {}", indent, err);
                return err;
            }
        case "img":
            if err := push_img(context, node, strings.concatenate({indent, "  "}, context.temp_allocator)); err != BufferError.None {
                fmt.eprintfln("[ERR]:{} --- Cannot prepare nodes for render: {}", indent, err);
                return err;
            }
        case:
            if err := push_node(context, node, strings.concatenate({indent, "  "}, context.temp_allocator)); err != BufferError.None {
                fmt.eprintfln("[ERR]:{} --- Cannot prepare nodes for render: {}", indent, err);
                return err;
            }
        }
    }

    ygg_ctx.renderer.state = RendererState.Prepared;
    fmt.printfln("[INFO]:{}--- Done", indent);
    return RendererError.None;
}

render_now :: proc "c" (
    viewport: [2]u32,
    pipeline: types.BufferPipeline) -> types.RendererError {
    using types;

    // Used to later revert buffers, program, and states
    // Don't assume we are the only renderer active, properly revert everything
    last_vao, vao_exists := get_last_vao();
    last_vbo, vbo_exists := get_last_vbo();
    last_program, exists := get_last_program();

    gl.Enable(gl.DEPTH_TEST);     // Use z-index to determine layer order
    gl.Enable(gl.STENCIL_TEST);   // Ability to round corners
    gl.Disable(gl.CULL_FACE);     // No need to cull faces as we do not convern ourselves with 3D yet

    // Blend box brackgrounds
    gl.Enable(gl.BLEND);
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

    // READ from UI, DRAW to surface (0)
    gl.BindFramebuffer(gl.READ_FRAMEBUFFER, pipeline.framebuffer.id)
    gl.BindFramebuffer(gl.DRAW_FRAMEBUFFER, 0)

    // Copy the UI FBO onto the surface FBO
    gl.BlitFramebuffer(
    0, 0, i32(viewport[0]), i32(viewport[1]), // Source Rect
    0, 0, i32(viewport[0]), i32(viewport[1]), // Dest Rect
    gl.COLOR_BUFFER_BIT,
    gl.LINEAR
    )

    // Bind buffers and use UI shader
    gl.BindFramebuffer(gl.FRAMEBUFFER, pipeline.framebuffer.id)
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    gl.UseProgram(pipeline.program);
    gl.BindVertexArray(pipeline.vao.id);
    gl.BindBuffer(gl.ARRAY_BUFFER, pipeline.vbo.id);

    gl.DrawArrays(gl.TRIANGLE_STRIP, 0, i32(pipeline.vbo.count));

    if vao_exists && vbo_exists {
        gl.BindBuffer(gl.ARRAY_BUFFER, last_vbo);
    }

    if vao_exists {
        gl.BindVertexArray(last_vao);
    }

    if exists {
        gl.UseProgram(last_program);
    }

    gl.Disable(gl.STENCIL_TEST);
    gl.Enable(gl.CULL_FACE);
    gl.Disable(gl.BLEND);

    return RendererError.None;
}

@(private)
update_viewport_and_camera :: proc "c" (width, height: i32, indent: string = "  ") -> types.Error {
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
create_initial_buffers :: proc "c" (indent: string = "  ") -> (types.Buffer, types.Buffer) {
    using types;

    context = runtime.default_context();

    fmt.printfln("[INFO]:{}| Creating initial buffers for rendering ... ", indent);

    new_indent, err := strings.concatenate({indent, "  "}, context.temp_allocator);
    assert_contextless(err == mem.Allocator_Error.None, "[ERR]:\tCannot create renderer: Out of memory (buy more ram)");

    vao_buffer, _ := create_buffer(BufferType.Vao, capacity = 1, indent = new_indent);
    vbo_buffer, _ := create_buffer(BufferType.Vbo, indent = new_indent);

    last_vao_bound : i32 = 0;
    last_vbo_bound : i32 = 0;

    gl.GetIntegerv(gl.VERTEX_ARRAY_BINDING, &last_vao_bound);
    gl.GetIntegerv(gl.ARRAY_BUFFER_BINDING, &last_vbo_bound);

    gl.BindVertexArray(vao_buffer.id);
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo_buffer.id);

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

    return vao_buffer, vbo_buffer;
}