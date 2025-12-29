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
import ex     "../examples";

config : map[string]string = {
  "test_mode" = "true",
  "headless"  = "true",
  "log_level" = "v"
};

setup :: proc (t: ^testing.T) -> types.Context {
  using types;
  using utils;

  ctx, err := ygg.create_context(config = config);
  if err != ContextError.None {
    fmt.eprintln("[ERR]:\t| Cannot create context: {}", err);
    testing.fail_now(t, "Cannot create context");
  }
  context.user_ptr = &ctx;  // Temp
  context.allocator = ctx.allocator;

  node := ygg.create_node(context, "root");
  ygg.attach_node(context, node);
  return ctx;
}


@(test)
create_duplicate :: proc (t: ^testing.T) {
  using types;

  ctx := setup(t);
  context.user_ptr = &ctx;
  context.allocator = ctx.allocator;

  defer ygg.destroy_context(context);

  first  := ygg.create_node(context, "head", utils.some(1));
  second := ygg.create_node(context, "head2", utils.some(1));

  ygg.attach_node(context, first);
  ygg.attach_node(context, second);
}

@(test)
find_node :: proc (t: ^testing.T) {
  using types;
  using utils;

  ctx := setup(t);
  context.user_ptr = &ctx;
  context.allocator = ctx.allocator;

  defer ygg.destroy_context(context);
  
  head_node := ygg.create_node(context, "head");
  link_node := ygg.create_node(context, "link", parent = &head_node);
  a_node    := ygg.create_node(context, "a", parent = &link_node);

  node_ptr := ygg.find_node(context, 2);
  testing.expect(t, node_ptr == nil, "A tag should not be found, since it is not attached to the tree");

  ygg.attach_node(context, head_node);
  ygg.attach_node(context, link_node);
  ygg.attach_node(context, a_node);
}

@(test)
max_depth :: proc (t: ^testing.T) {
  using types;
  using utils;

  ctx := setup(t);
  context.user_ptr = &ctx;
  context.allocator = ctx.allocator;

  defer ygg.destroy_context(context);

  max_node_depth: Id = Id(get_max_number(Id));
  lvl_1: u16 = (max_node_depth / 16) + 1;

  for _ in 0..=lvl_1 - 1 {
    node := ygg.create_node(context, "head");
    ygg.attach_node(context, node);
  }

  testing.expect_value(t, ygg.get_node_depth(ctx.root, context.temp_allocator), lvl_1);

  lvl_2: u16 = lvl_1 * 4;   // 16k


  for _ in lvl_1..=lvl_2 - 1 {
    node  := ygg.create_node(context, "head");
    ygg.attach_node(context, node);
  }

  testing.expect_value(t, ygg.get_node_depth(ctx.root, context.temp_allocator), lvl_2);

  lvl_3: u16 = lvl_2 * 4;


  for _ in lvl_2..=lvl_3 - 1 {
    node := ygg.create_node(context, "head");
    ygg.attach_node(context, node);
  }

  testing.expect_value(t, ygg.get_node_depth(ctx.root, context.temp_allocator), lvl_3);
}

@(test)
id_overflow :: proc (t: ^testing.T) {
  using types;

  ctx := setup(t);
  context.user_ptr = &ctx;
  context.allocator = ctx.allocator;

  defer ygg.destroy_context(context);

  head  := ygg.create_node(context, tag = "head", id = utils.some(65_536));
  title := ygg.create_node(context, tag = "title", parent = &head);
  link  := ygg.create_node(context, tag = "link", parent = &head);

  testing.expect(t, head.id == 0, "Expected node id to overflow back to 0");

  ygg.attach_node(context, head);
  ygg.attach_node(context, title);
  ygg.attach_node(context, link);

  testing.expect(t, ctx.root.tag == "head", "Expected head to now be root due to overflow");
  testing.expect_value(t, ygg.get_node_depth(ctx.root, context.temp_allocator), 1);
}

//@(test)
//retained :: proc (t: ^testing.T) {
//  ex.hello_retained();
//}
//
//@(test)
//immediate :: proc (t: ^testing.T) {
//  ex.hello_immediate();
//}
