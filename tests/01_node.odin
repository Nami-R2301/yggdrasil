#+feature dynamic-literals
package tests;

import "core:testing";
import "core:fmt";
import "vendor:glfw";

import ygg "../src";
import types "../src/types";
import utils "../src/utils";

config : map[string]string = {
  "test_mode" =  "true",
  "headless"  =  "true",
  "log_level" =  "v"
};

setup :: proc (t: ^testing.T) -> types.Context {
  using types;
  using ygg;
  using utils;

  result := _create_context(config = config);
  if result.error != ContextError.None {
    fmt.eprintln("[ERR]:\t| Cannot create context: {}", result.error);
    testing.fail_now(t, "Cannot create context");
  }
  
  ctx := unwrap(result.opt);
  node  := _create_node(&ctx, "root");
  error := _attach_node(&ctx, node);
  assert(error == NodeError.None, "Error attaching root node");

  if error != NodeError.None {
    fmt.eprintln("[ERR]:\t| Cannot create context: {}", error);
    testing.fail_now(t,"Cannot create context");
  }

  return ctx;
}

cleanup :: proc (ctx: ^types.Context) {
  using ygg;

  error := _destroy_context(ctx);

  assert(error == types.ContextError.None, "Error during test cleanup");
}


@(test)
create_duplicate :: proc (t: ^testing.T) {
  using types;
  using ygg;

  ctx := setup(t);
  defer cleanup(&ctx);

  first  := _create_node(&ctx, "head", utils.some(1));
  second := _create_node(&ctx, "head2", utils.some(1));

  error := _attach_node(&ctx, first);
  error = _attach_node(&ctx, second);

  testing.expect_value(t, error, NodeError.None);
}

@(test)
find_node :: proc (t: ^testing.T) {
  using types;
  using ygg;
  using utils;
  
  ctx := setup(t);
  defer cleanup(&ctx);
  
  head_node  := _create_node(&ctx, "head");
  link_node  := _create_node(&ctx, "link", parent = &head_node);
  a_node     := _create_node(&ctx, "a", parent = &link_node);

  node_ptr := find_node(&ctx, 2);
  testing.expect(t, node_ptr == nil, "A tag should not be found, since it is not attached to the tree");

  error := _attach_node(&ctx, head_node);
  testing.expect(t, error == NodeError.None, "Error attaching <head> node");
  
  error = _attach_node(&ctx, link_node);
  testing.expect(t, error == NodeError.None, "Error attaching <link> node");
  
  error = _attach_node(&ctx, a_node);
  testing.expect(t, error == NodeError.None, "Error attaching <a> node");
}

@(test)
max_depth :: proc (t: ^testing.T) {
  using types;
  using utils;
  using ygg;

  ctx := setup(t);
  defer cleanup(&ctx);

  max_node_depth: types.Id = types.Id(_get_max_number(types.Id));
  lvl_1: u16 = (max_node_depth / 16) + 1;

  for _ in 0..=lvl_1 - 1 {
    node  := _create_node(&ctx, "head");
    error := _attach_node(&ctx, node);
    assert(error == NodeError.None, "Error attaching node");
  }

  testing.expect_value(t, _get_node_depth(ctx.root), lvl_1);

  lvl_2: u16 = lvl_1 * 4;   // 16k


  for _ in lvl_1..=lvl_2 - 1 {
    node  := _create_node(&ctx, "head");
    error := _attach_node(&ctx, node);
    assert(error == NodeError.None, "Error attaching node");
  }


  testing.expect_value(t, _get_node_depth(ctx.root), lvl_2);

  lvl_3: types.Id = lvl_2 * 4;


  for _ in lvl_2..=lvl_3 - 1 {
    node  := _create_node(&ctx, "head");
    error := _attach_node(&ctx, node);
    assert(error == NodeError.None, "Error attaching node");
  }

  testing.expect_value(t, _get_node_depth(ctx.root), lvl_3);
}

@(test)
id_overflow :: proc (t: ^testing.T) {
  using types;

  ctx := setup(t);
  defer cleanup(&ctx);

  head  := ygg._create_node(&ctx, tag = "head", id = utils.some(65_536));
  title := ygg._create_node(&ctx, tag = "title", parent = &head);
  link  := ygg._create_node(&ctx, tag = "link", parent = &head);
  testing.expect(t, head.id == 0, "Expected node id to overflow back to 0");

  error := ygg._attach_node(&ctx, head);
  error  = ygg._attach_node(&ctx, title);
  error  = ygg._attach_node(&ctx, link);
  testing.expect(t, ctx.root.tag == "head", "Expected head to now be root due to overflow");
  testing.expect_value(t, ygg._get_node_depth(ctx.root), 1);
}

@(test)
simple :: proc (t: ^testing.T) {
  using types;
  using utils;

  // Manual configs. Specify 'none' for any config values you wish to leave/reset default.
  temp_config: map[string]string = {};
  defer delete_map(temp_config);

  // Can specify 0-4 for verbosity, 1 being normal and 4 being everything, 0 to disable. Defaults to normal.
  temp_config["log_level"]    = "vvv";
  temp_config["log_file"]     = "logs.txt";
  // indicate if this app requires a renderer or not (true/false). Defaults to false.
  temp_config["headless"]     = "true";
  temp_config["optimization"] = "release";
  temp_config["cache"]        = "";
  temp_config["renderer"]     = "";

  result_window := ygg._create_window("Simple");
  assert(result_window.error == WindowError.None, "Error creating window");
  window_handle := unwrap(result_window.opt);

  result_ctx := ygg._create_context(window_handle = &window_handle, config = temp_config);
  assert(result_ctx.error == ContextError.None, "Error creating main context");
  ctx := unwrap(result_ctx.opt);
  defer ygg._destroy_context(&ctx);

  head  := ygg._create_node(&ctx, tag = "head");
  link  := ygg._create_node(&ctx, tag = "link");
  link2 := ygg._create_node(&ctx, tag = "link", parent = &head);

  error := ygg._attach_node(&ctx, head);
  error =  ygg._attach_node(&ctx, link);
  error =  ygg._attach_node(&ctx, link2);

  node := ygg.find_node(&ctx, 2);
  ygg.print_nodes(node);
}
