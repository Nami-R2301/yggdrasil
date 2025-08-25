package examples;

import "vendor:raylib";
import "vendor:glfw";
import "core:fmt";

import "../src/core";

main :: proc () {
  using core;

  ctx: Context = create_context();
  _, wrapped_head := create_node(&ctx, 1, "head", none(Node));
  _, wrapped_link := create_node(&ctx, 2, "link", none(Node)); 

  head := unwrap(wrapped_head);
  link := unwrap(wrapped_link);

  error := attach_node(&ctx, head, none(u16));
  error = attach_node(&ctx, link, some(head.id));

  print_nodes(ctx.root);

  for bool(!glfw.WindowShouldClose(ctx.window)) {
    
    glfw.PollEvents();
    glfw.SwapBuffers(ctx.window);
  }

  defer destroy_context(ctx);
}

