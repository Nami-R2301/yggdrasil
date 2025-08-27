package examples;

import "vendor:raylib";
import "vendor:glfw";
import "core:fmt";

import "../src/core";

main :: proc () {
  using core;

  temp_config: map[string]Option(string) = {};
  temp_config["debug_level"] = some("Everything");

  error, ctx_opt := create_context(config = temp_config);
  assert(error == Error.None && is_some(ctx_opt), "Error Initializing Context, please check logs or turn on maximum verbosity '-vvv' if missing logs...");

  ctx := unwrap(ctx_opt);

  head := create_node(&ctx, 1, "head");
  link := create_node(&ctx, 2, "link"); 

  error = attach_node(&ctx, head);
  error = attach_node(&ctx, link);

  print_nodes(ctx.root);

  for bool(!glfw.WindowShouldClose(ctx.window)) {
    
    glfw.PollEvents();
    glfw.SwapBuffers(ctx.window);
  }

  defer destroy_context(&ctx);
}

