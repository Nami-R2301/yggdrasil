#+feature dynamic-literals
package examples;

import core  "../src";
import im    "../src/immediate";
import rt    "../src/retained";

hello_immediate :: proc () {
    ctx, _ := core.create_context(config = {
        "log_level" = "vvv"
    });
    // We pass the context using odin's context, so this step is crucial for subsequent api calls
    context.user_ptr  = &ctx;

    defer core.destroy_context(context);

    // Main loop - all nodes will be re-rendered on each frame (immediate mode).
    for core.is_window_running(ctx.window) {
        core.poll_events(ctx.window);
        im.begin_frame(context);  // Reset nodes and start capturing new frame layout from here.

        // Text box in the middle of the screen (absolute)
        im.text(context, content = "Hello World!", is_inline = true, style = {
            "position"      = "(abs,center)",  // Absolute center of viewport
            "box-size"      = "(400px,200px)", // Width 400px, height 200px
            "box-color"     = "0x1818FF",
            "font-size"     = "32px",          // <h1/>
            "text-align"    = "center",
        });

        im.end_frame(context);  // Validate nodes & draw if rendering is toggled on.
        core.swap_buffers(ctx.window);
    }
}

hello_retained :: proc () {
    ctx, _ := core.create_context(config = {
        "log_level" = "vvv"
    });
    context.user_ptr  = &ctx;

    defer core.destroy_context(context);


    // Add text in box at the root of the tree (omitted parent_ptr arg)
//    text := rt.text(context, content = "Hello World!", style = {
//        "position"   = "(abs,center)",
//        "box-size"   = "(400px,200px)",
//        "box-color"  = "0x1818FF",
//        "font-size"  = "32px",
//        "text-align" = "center"
//    });
//    // Need to call this explicitely before rendering in retained mode, unlike immediate
//    _     = core.prepare_nodes(context, nodes = {&text});

    for core.is_window_running(ctx.window) {
        core.poll_events(ctx.window);

        // Draw all node data in the VBO
        core.render_now(viewport = ctx.window.dimensions, pipeline = ctx.renderer.pipeline);

        core.swap_buffers(ctx.window);
    }
}