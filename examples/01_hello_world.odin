#+feature dynamic-literals
package examples;

import core  "../src";
import im    "../src/immediate";
import rt    "../src/retained";

hello_immediate :: proc () {
    ctx := core.create_context();
    defer core.destroy_context(ctx);
    context = ctx._context;

    // Main loop - all nodes will be re-rendered on each frame (immediate mode).
    for core.is_window_running(ctx.window) {
        core.poll_events(ctx.window);
        im.begin_frame(ctx);  // Reset nodes and start capturing new frame layout from here.

        // Text box in the middle of the screen (absolute)
        im.text(ctx, content = "Hello World!", is_inline = true, style = {
            "position"      = "abs, center",  // Absolute center of viewport
            "box-size"      = "400px, 200px", // Width 400px, height 200px
            "box-color"     = "0x1818FF",
            "font-size"     = "32px",          // <h1/>
            "text-align"    = "center",
        });

        im.end_frame(ctx);  // Validate nodes & draw if rendering is toggled on.
        core.swap_buffers(ctx.window);
    }
}

hello_retained :: proc () {
    window   := core.create_window("Test");
    renderer := core.create_renderer(&window);

    ctx := core.create_context(window_handle = &window, renderer_handle = &renderer);
    defer core.destroy_context(ctx);

    // Add text in box at the root of the tree (omitted parent_ptr arg)
    style_map := make(map[string]Maybe(string), ctx._context.allocator);
    style_map["position"]   = "center";
    style_map["box-size"]   = "400px, 200px";
    style_map["box-color"]  = "0x2C2C2CFF";
    style_map["font-size"]  = "32px";
    style_map["text-align"] = "center";

    defer delete_map(style_map);

    text := rt.text(ctx, content = "Hello my beautiful farah!", style = style_map);

    // Need to call this explicitely before rendering in retained mode, unlike immediate
    _ = core.prepare_nodes(ctx, nodes = {&text});

    for core.is_window_running(ctx.window) {
        core.poll_events(ctx.window);

        // Draw all node data in the VBO
        core.render_now(viewport = {ctx.window.width, ctx.window.height}, pipeline = ctx.renderer.pipeline);

        core.swap_buffers(ctx.window);
    }
}
