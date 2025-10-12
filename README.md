# Yggdrasil - HTML-like GUI

Yggdrasil is an Odin library to facilitate writing UI with tree nodes, inspired by the HTML doctype. You can also use this library for a headless setup, where you can record and store data nodes instead of renderable nodes to pass on to another program for instance.

## Features
- Immediate and retained mode APIs - give high and low level APIs for different use cases
- Data nodes - not all nodes are for rendering
- Import HTML and CSS directly for pre-made layouts 
- Export as HTML for web apps

## Pre-requisites
- glfw >3.3
- OpenGL >3.3

## Setup
Build & run tests:
```bash
make
```

## Hello World
```odin
import ygg "./src";
import utils "ygg:utils";

main :: proc () {
    using utils;

    result := ygg.init_context();
    assert(into_bool(result), "Error initializing context");
    ctx := unwrap(result.opt);
    defer ygg.terminate_context(&ctx);

    for bool(!glfw.WindowShouldClose(ctx.window.glfw_handle)) {
        ygg.begin_frame(&ctx);

        ygg.root(&ctx);
        {
            _, node_ptr := ygg.title(&ctx, "Hello World!", is_inline = true);
            node_ptr.style["position"]  = some("absolute");
            node_ptr.style["width"]     = some("100%");
            node_ptr.style["height"]    = some("100%");
            node_ptr.style["font-size"] = some("24px");
        }
        ygg.end_node(&ctx, "root");

        ygg.end_frame(&ctx);
    }
}
```

## Examples:

- Go to the specific example you want to build & run and uncomment the main procedure, then run:

```bash
make example && ./bin/<example_uncommented.odin>
```
