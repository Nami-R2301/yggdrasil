package yggdrasil;

import "vendor:raylib";
import "vendor:glfw";
import "core:fmt";

import "core";
import "ui";

main :: proc () {
  using core;

  ctx: Context = create_context();
  head: Node = ui.create_node(&ctx, "head");

  for bool(!glfw.WindowShouldClose(ctx.window)) {
    
    glfw.PollEvents();
    glfw.SwapBuffers(ctx.window);
  }

  defer destroy_context(ctx);
}

