package retained;

import fmt   "core:fmt";
import mem   "core:mem";
import gl    "vendor:OpenGL";

import ygg   "..";
import types "../types"
import strings "core:strings";

batch_nodes :: proc (
    nodes:          []^types.Node,
    indent:         string = "  ",
    allocator:      mem.Allocator = context.allocator) -> types.Error {
    using types;

    fmt.printfln("[INFO]:{}| Batching nodes for rendering ... ", indent);

    assert(context.user_ptr != nil, "[ERR]:\tCannot prepare nodes for render: Context is nil. Did you forget to set " +
    " context.user_ptr to 'ctx'?");
    ctx := cast(^Context)context.user_ptr;

    assert(ctx != nil && ctx.renderer != nil, "[ERR]:\tCannot prepare nodes for render: No renderer found or " +
        "nil. Did you forget to call 'create_renderer(...)'?");

    for node in nodes {
        switch node.tag {
        case "text":
            if err := ygg.push_text(node, strings.concatenate({indent, "  "}, context.temp_allocator)); err != BufferError.None {
                fmt.eprintfln("[ERR]:{} --- Cannot prepare nodes for render: {}", indent, err);
                return err;
            }
        case "box":
            if err := ygg.push_box(node, strings.concatenate({indent, "  "}, context.temp_allocator)); err != BufferError.None {
                fmt.eprintfln("[ERR]:{} --- Cannot prepare nodes for render: {}", indent, err);
                return err;
            }
        case "img":
            if err := ygg.push_img(node, strings.concatenate({indent, "  "}, context.temp_allocator)); err != BufferError.None {
                fmt.eprintfln("[ERR]:{} --- Cannot prepare nodes for render: {}", indent, err);
                return err;
            }
        case:
            if err := ygg.push_node(node, strings.concatenate({indent, "  "}, context.temp_allocator)); err != BufferError.None {
                fmt.eprintfln("[ERR]:{} --- Cannot prepare nodes for render: {}", indent, err);
                return err;
            }
        }
    }

    ctx.renderer.state = RendererState.Prepared;
    fmt.printfln("[INFO]:{}--- Done", indent);
    return RendererError.None;
}

render_now :: proc (indent: string = "  ") -> types.RendererError {
    using types;

    if context.user_ptr == nil {
        fmt.eprintfln("[ERR]:{}| Cannot render now: Current context is nil. Skipping ...", indent);
        return RendererError.InitError;
    }

    ctx: ^Context = cast(^Context)context.user_ptr;
    if ctx.renderer == nil {
        fmt.eprintfln("[ERR]:{}| Cannot render now: renderer is nil. Skipping ...", indent);
        return RendererError.InvalidRenderer;
    }

    // Used to later revert buffers, program, and states
    // Don't assume we are the only renderer active, properly revert everything
    last_vao, vao_exists := ygg.get_last_vao();
    last_vbo, vbo_exists := ygg.get_last_vbo();
    last_program, exists := ygg.get_last_program();

    gl.Enable(gl.DEPTH_TEST);     // Use z-index to determine layer order
    gl.Enable(gl.STENCIL_TEST);   // Ability to round corners
    gl.Disable(gl.CULL_FACE);     // No need to cull faces as we do not convern ourselves with 3D yet

    // Blend box brackgrounds
    gl.Enable(gl.BLEND);
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

    // READ from UI, DRAW to surface (0)
    gl.BindFramebuffer(gl.READ_FRAMEBUFFER, ctx.renderer.framebuffer.id)
    gl.BindFramebuffer(gl.DRAW_FRAMEBUFFER, 0)

    // Copy the UI FBO onto the surface FBO
    gl.BlitFramebuffer(
    0, 0, i32(ctx.window.dimensions[0]), i32(ctx.window.dimensions[1]), // Source Rect
    0, 0, i32(ctx.window.dimensions[0]), i32(ctx.window.dimensions[1]), // Dest Rect
    gl.COLOR_BUFFER_BIT,
    gl.LINEAR
    )

    // Bind buffers and use UI shader
    gl.BindFramebuffer(gl.FRAMEBUFFER, ctx.renderer.framebuffer.id)
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    gl.UseProgram(ctx.renderer.program);
    gl.BindVertexArray(ctx.renderer.vao.id);
    gl.BindBuffer(gl.ARRAY_BUFFER, ctx.renderer.vbo.id);

    gl.DrawArrays(gl.TRIANGLE_STRIP, 0, i32(ctx.renderer.vbo.count));

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

