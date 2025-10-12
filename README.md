# Yggdrasil - HTML-like UI to Ease Rendering of UI Elements

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
import ygg "../src";
import types "../src/types";
import utils "../src/utils";

main :: proc () {
    using types;
    using utils;

    result := ygg.init_context();
    assert(into_bool(result), "Error initializing context");
    ctx := unwrap(result.opt);
    defer ygg.terminate_context(&ctx);

    for bool(!glfw.WindowShouldClose(ctx.window.glfw_handle)) {
        ygg.begin_frame(&ctx);

        ygg.root(&ctx);
        {
            ygg.head(&ctx);
            {
                ygg.link(&ctx, is_inline = true);
                ygg.link(&ctx, is_inline = true);
            }
            ygg.end_node(&ctx, "head");
        }
        ygg.end_node(&ctx, "root");

        ygg.end_frame(&ctx);
    }
}
```

## Examples:

- Go to the specific example you want to build & run and uncomment the main procedure - let's take the first one (01_immediate.odin):

```bash
odin run -collection:yggdrasil=./src -file 01_immediate.odin
```
