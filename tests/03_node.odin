package tests;

import "core:testing";
import "core:fmt";
import "vendor:glfw";

import ygg "../src";
import rt "../src/retained";
import types "../src/types";
import utils "../src/utils";

setup :: proc (t: ^testing.T) -> types.Context {
  using types;
  using ygg;
  using utils;

  config : map[string]string = {};

  config["test_mode"] = "true";
  config["headless"]  = "true";
  config["log_level"] = "v";

  result := rt.create_context(config = config);
  if result.error != ContextError.None {
    fmt.eprintln("[ERR]:\t| Cannot create context: {}", result.error);
    testing.fail_now(t, "Cannot create context");
  }
  
  ctx := unwrap(result.opt);
  node  := rt.create_node(&ctx, "root");
  error := rt.attach_node(&ctx, node);
  assert(error == NodeError.None, "Error attaching root node");

  if error != NodeError.None {
    fmt.eprintln("[ERR]:\t| Cannot create context: {}", error);
    testing.fail_now(t,"Cannot create context");
  }

  return ctx;
}

cleanup :: proc (ctx: ^types.Context) {
  using ygg;

  error := rt.destroy_context(ctx);

  assert(error == types.ContextError.None, "Error during test cleanup");
}


@(test)
create_duplicate :: proc (t: ^testing.T) {
  using types;
  using ygg;

  ctx := setup(t);
  defer cleanup(&ctx);

  first  := rt.create_node(&ctx, "head", utils.some(1));
  second := rt.create_node(&ctx, "head2", utils.some(1));

  error := rt.attach_node(&ctx, first);
  error = rt.attach_node(&ctx, second);

  testing.expect_value(t, error, NodeError.None);
}

@(test)
find_node :: proc (t: ^testing.T) {
  using types;
  using ygg;
  using utils;
  
  ctx := setup(t);
  defer cleanup(&ctx);
  
  head_node  := rt.create_node(&ctx, "head");
  link_node  := rt.create_node(&ctx, "link", parent = &head_node);
  a_node     := rt.create_node(&ctx, "a", parent = &link_node);

  node_ptr := find_node(&ctx, 2);
  testing.expect(t, node_ptr == nil, "A tag should not be found, since it is not attached to the tree");

  error := rt.attach_node(&ctx, head_node);
  testing.expect(t, error == NodeError.None, "Error attaching <head> node");
  
  error = rt.attach_node(&ctx, link_node);
  testing.expect(t, error == NodeError.None, "Error attaching <link> node");
  
  error = rt.attach_node(&ctx, a_node);
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
    node  := rt.create_node(&ctx, "head");
    error := rt.attach_node(&ctx, node);
    assert(error == NodeError.None, "Error attaching node");
  }

  testing.expect_value(t, ygg.get_node_depth(ctx.root), lvl_1);

  lvl_2: u16 = lvl_1 * 4;   // 16k


  for _ in lvl_1..=lvl_2 - 1 {
    node  := rt.create_node(&ctx, "head");
    error := rt.attach_node(&ctx, node);
    assert(error == NodeError.None, "Error attaching node");
  }


  testing.expect_value(t, ygg.get_node_depth(ctx.root), lvl_2);

  lvl_3: types.Id = lvl_2 * 4;


  for _ in lvl_2..=lvl_3 - 1 {
    node  := rt.create_node(&ctx, "head");
    error := rt.attach_node(&ctx, node);
    assert(error == NodeError.None, "Error attaching node");
  }

  testing.expect_value(t, ygg.get_node_depth(ctx.root), lvl_3);
}

@(test)
id_overflow :: proc (t: ^testing.T) {
  using types;

  ctx := setup(t);
  defer cleanup(&ctx);

  head  := rt.create_node(&ctx, tag = "head", id = utils.some(65_536));
  title := rt.create_node(&ctx, tag = "title", parent = &head);
  link  := rt.create_node(&ctx, tag = "link", parent = &head);
  testing.expect(t, head.id == 0, "Expected node id to overflow back to 0");

  error := rt.attach_node(&ctx, head);
  error  = rt.attach_node(&ctx, title);
  error  = rt.attach_node(&ctx, link);
  testing.expect(t, ctx.root.tag == "head", "Expected head to now be root due to overflow");
  testing.expect_value(t, ygg.get_node_depth(ctx.root), 1);
}
