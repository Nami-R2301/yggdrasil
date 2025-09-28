package examples;

import "vendor:raylib";
import "vendor:glfw";
import "core:fmt";

import ygg "../src";
import "yggdrasil:utils";
import "yggdrasil:types";

main :: proc () {
  using types;

  // Manual configs. Specify 'none' for any config values you wish to leave/reset default.
  temp_config: map[string]Option(string) = {};
   
   // Can specify 0-4 for verbosity, 1 being normal and 4 being everything, 0 to disable. Defaults to normal.
  temp_config["log_level"]    = utils.some("v");
  // indicate if this app requires a renderer or not (true/false). Defaults to false.
  temp_config["headless"]     = utils.some("true");
  temp_config["optimization"] = utils.some("release");
  temp_config["cache"]        = utils.none(string);
  temp_config["renderer"]     = utils.none(string);

  error, ctx_opt := ygg._create_context(config = temp_config);
  assert(error == ContextError.None, "Error creating main context");
  ctx := utils.unwrap(ctx_opt);

  head  := ygg._create_node(ctx = &ctx, id = 1, tag = "head");
  link  := ygg._create_node(ctx = &ctx, id = 2, tag = "link");
  link2 := ygg._create_node(ctx = &ctx, id = 3, tag = "link");

  error = ygg._attach_node(&ctx, head);
  error = ygg._attach_node(&ctx, link);
  error = ygg._attach_node(&ctx, link2);
  
  ygg.print_nodes(ctx.root);

  headless_mode: bool = utils.into_bool(ctx.config["headless"]);
  if !headless_mode {
    for bool(!glfw.WindowShouldClose(ctx.window)) {
      glfw.PollEvents();
      glfw.SwapBuffers(ctx.window);
    }
  }

  defer ygg._destroy_context(&ctx);
}

