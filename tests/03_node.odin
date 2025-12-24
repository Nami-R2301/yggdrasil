#+feature dynamic-literals
package tests;

import testing  "core:testing";
import fmt      "core:fmt";
import strings  "core:strings";
import glfw     "vendor:glfw";
import vmem     "core:mem/virtual";
import mem      "core:mem";

import ygg    "../src";
import rt     "../src/retained";
import types  "../src/types";
import utils  "../src/utils";

config : map[string]string = {
  "test_mode" = "true",
  "headless"  = "true",
  "log_level" = "v"
};

setup :: proc (t: ^testing.T) -> types.Context {
  using types;
  using utils;

  ctx, err := rt.create_context(config = config);
  if err != ContextError.None {
    fmt.eprintln("[ERR]:\t| Cannot create context: {}", err);
    testing.fail_now(t, "Cannot create context");
  }
  context.user_ptr = &ctx;  // Temp

  node := rt.create_node("root");
  rt.attach_node(node);
  return ctx;
}


@(test)
create_duplicate :: proc (t: ^testing.T) {
  using types;

  ctx := setup(t);
  context.user_ptr = &ctx;

  defer rt.destroy_context(&ctx);

  first  := rt.create_node("head", utils.some(1));
  second := rt.create_node("head2", utils.some(1));

  rt.attach_node(first);
  rt.attach_node(second);
}

@(test)
find_node :: proc (t: ^testing.T) {
  using types;
  using utils;

  ctx := setup(t);
  context.user_ptr = &ctx;

  defer rt.destroy_context(&ctx);
  
  head_node := rt.create_node("head");
  link_node := rt.create_node("link", parent = &head_node);
  a_node    := rt.create_node("a", parent = &link_node);

  node_ptr := ygg.find_node(2);
  testing.expect(t, node_ptr == nil, "A tag should not be found, since it is not attached to the tree");

  rt.attach_node(head_node);
  rt.attach_node(link_node);
  rt.attach_node(a_node);
}

@(test)
max_depth :: proc (t: ^testing.T) {
  using types;
  using utils;

  ctx := setup(t);
  context.user_ptr = &ctx;

  defer rt.destroy_context(&ctx);

  max_node_depth: Id = Id(_get_max_number(Id));
  lvl_1: u16 = (max_node_depth / 16) + 1;

  for _ in 0..=lvl_1 - 1 {
    node := rt.create_node("head");
    rt.attach_node(node);
  }

  testing.expect_value(t, ygg.get_node_depth(ctx.root), lvl_1);

  lvl_2: u16 = lvl_1 * 4;   // 16k


  for _ in lvl_1..=lvl_2 - 1 {
    node  := rt.create_node("head");
    rt.attach_node(node);
  }

  testing.expect_value(t, ygg.get_node_depth(ctx.root), lvl_2);

  lvl_3: u16 = lvl_2 * 4;


  for _ in lvl_2..=lvl_3 - 1 {
    node := rt.create_node("head");
    rt.attach_node(node);
  }

  testing.expect_value(t, ygg.get_node_depth(ctx.root), lvl_3);
}

@(test)
id_overflow :: proc (t: ^testing.T) {
  using types;

  ctx := setup(t);
  context.user_ptr = &ctx;

  defer rt.destroy_context(&ctx);

  head  := rt.create_node(tag = "head", id = utils.some(65_536));
  title := rt.create_node(tag = "title", parent = &head);
  link  := rt.create_node(tag = "link", parent = &head);

  testing.expect(t, head.id == 0, "Expected node id to overflow back to 0");

  rt.attach_node(head);
  rt.attach_node(title);
  rt.attach_node(link);

  testing.expect(t, ctx.root.tag == "head", "Expected head to now be root due to overflow");
  testing.expect_value(t, ygg.get_node_depth(ctx.root), 1);
}
