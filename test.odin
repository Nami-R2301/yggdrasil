package yggdrasil;

import "vendor:raylib";
import "vendor:glfw";
import "core:fmt";

import "core";

main :: proc () {

  ctx: Context = core.create_context();
  head: Node = create_node(&ctx, "head");
  
  print_nodes(&ctx.root);

  for bool(!glfw.WindowShouldClose(ctx.window)) {
    
    glfw.PollEvents();
    glfw.SwapBuffers(ctx.window);
  }

  defer destroy_context(ctx);
}

