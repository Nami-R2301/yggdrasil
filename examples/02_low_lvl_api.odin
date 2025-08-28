package examples;

import "vendor:raylib";
import "vendor:glfw";
import "core:fmt";

import ygg "../src";
import "yggdrasil:utils";
import "yggdrasil:types";

main :: proc () {
  using types;

  temp_config: map[string]Option(string) = {};
  temp_config["debug_level"] = utils.some("Everything");

  error, ctx_opt := ygg._create_context(config = temp_config);
  assert(error == ContextError.None, "Error creating main context");
  ctx := utils.unwrap(ctx_opt);

  head := ygg._create_node(&ctx, 1, "head");
  link := ygg._create_node(&ctx, 2, "link"); 

  error = ygg._attach_node(&ctx, head);
  error = ygg._attach_node(&ctx, link);

  ygg.print_nodes(ctx.root);

  for bool(!glfw.WindowShouldClose(ctx.window)) {
    
    glfw.PollEvents();
    glfw.SwapBuffers(ctx.window);
  }

  defer ygg._destroy_context(&ctx);
}

