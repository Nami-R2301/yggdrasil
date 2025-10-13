# Yggdrasil - HTML-like GUI

Yggdrasil is an Odin library to facilitate writing UI with tree nodes, inspired by the HTML doctype. You can also use this library for a headless setup, where you can record and store data nodes instead of renderable nodes to pass on to another program for instance.

## tl;dr (Immediate mode)
```odin
import im    "../src/immediate";
import types "../src/types";
import utils "../src/utils";

main :: proc () {
    using types;
    using utils;

    result := im.init_context();
    ctx := unwrap(result.opt);

    for bool(!glfw.WindowShouldClose(ctx.window.glfw_handle)) {
        im.begin_frame(&ctx);  // Reset nodes and start capturing new frame layout from here.

        im.root(&ctx);  // <root>
        {
            im.head(&ctx);  // <head>
            {
                result   := im.title(&ctx, "Hello World!", is_inline = true);  // <h1 />
                node_ptr := unwrap(result.opt);

                // Position at center of the screen with a slighty bigger font.
                node_ptr.style["position"]      = some("absolute");
                node_ptr.style["width"]         = some("100%");
                node_ptr.style["height"]        = some("100%");
                node_ptr.style["center"]        = some("1"); // Flex + justify-center + items-center + m-auto.
                node_ptr.style["font-size"]     = some("32px");
            }
            im.end_node(&ctx, "head");  // </head>
        }
        im.end_node(&ctx, "root");  // </root>

        im.end_frame(&ctx);  // Validate nodes & draw if rendering is toggled on.
    }
}
```

## tl;dr (Retained mode)
```odin
import ygg   "../src";
import rt    "../src/retained";
import types "../src/types";
import utils "../src/utils";

main :: proc () {
    using types;
    using utils;

    result_window := ygg.create_window("Retained Mode");
    window_handle := unwrap(result_window.opt);

    result_renderer := ygg.create_renderer(bg_color = 0x222222);
    renderer_handle := unwrap(result_renderer.opt);

    // Unlike the immediate mode example, in the retained mode API you MUST provide the window & renderer handles to
    // 'create_context()' IF you plan on endering your nodes onto a surface.
    ctx_result := rt.create_context(window_handle = &window_handle, renderer_handle = &renderer_handle, config = {
        "log_level" = "vvv"
    });
    ctx := unwrap(ctx_result.opt);

    head  := rt.create_node(&ctx, tag = "head");
    title := rt.create_node(&ctx, tag = "title", parent = &head);

    node_error := rt.attach_node(&ctx, head);
    node_error  = rt.attach_node(&ctx, title);

    buffer_result := rt.create_buffer(BufferType.vbo);
    buffer := unwrap(buffer_result.opt);

    // Serialize the node styles into recognizable draw properties and compile the vertices into compact bytes.
    serde_result  := rt.serialize_nodes({ head, title });

    // Set the buffer to its respective type, bind it, and optionally init with given data.
    buffer_error  := rt.prepare_buffer(&buffer, data = unwrap(serde_result.opt));

    // IMPORTANT: Add the newly created buffer into the main rendering pipeline.
    rt.attach_buffer(&renderer_handle, &buffer);

    headless_mode : bool = into_bool(ctx.config["headless"]);
    if !headless_mode {
        for bool(!glfw.WindowShouldClose(ctx.window.glfw_handle)) {
            glfw.PollEvents();
            // Bind the shader, vao, and draw the vertices in the main vbo containing all node data.
            rt.render_now(ctx.renderer);
            glfw.SwapBuffers(ctx.window.glfw_handle);
        }
    }
}
```

## Features
- Immediate and retained mode APIs - give high and low level APIs for different use cases
- Data nodes - not all nodes are for rendering
- Import HTML and CSS directly for pre-made layouts
- Export as HTML for web apps

## Pre-requisites
- glfw >3.3
- OpenGL >3.3

## Setup
Build examples & run tests:
```bash
make
```

## Examples:

- All examples are compiled into `index.odin` and executed sequentially. Remove or comment all examples you don't want in the final binary, then run:

```bash
make example && ./bin/examples.odin
```
