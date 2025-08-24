package yggdrasil;

import "vendor:raylib";
import "vendor:glfw";
import "core:fmt";

import "core";

main :: proc () {
  using core;

  ctx: Context = create_context();
  head: Node = create_node(&ctx, "head");
  
  error := add_node(&ctx, head);
  if error != Error.None {
    fmt.eprintfln("[ERR]:\t  --- Error adding node to tree: {}", error);
  }

  print_nodes(ctx.root);

  for bool(!glfw.WindowShouldClose(ctx.window)) {
    
    glfw.PollEvents();
    glfw.SwapBuffers(ctx.window);
  }

  defer destroy_context(ctx);
}

