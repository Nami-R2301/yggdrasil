#+feature dynamic-literals
package tests;

import testing  "core:testing";

import ygg    "../src";
import types  "../src/types";
import utils  "../src/utils";
import ex     "../examples";

config : map[string]string = {
  "test_mode" = "true",
  "headless"  = "true",
  "log_level" = "v"
};

setup :: proc (t: ^testing.T) -> ^types.Context {
  ctx := ygg.create_context(config = &config);
  node := ygg.create_node(ctx, "root");
  ygg.attach_node(ctx, node);
  return ctx;
}


@(test)
create_duplicate :: proc (t: ^testing.T) {
  ctx := setup(t);
  defer ygg.destroy_context(ctx);

  first  := ygg.create_node(ctx, "head", 1);
  second := ygg.create_node(ctx, "head2", 1);

  ygg.attach_node(ctx, first);
  ygg.attach_node(ctx, second);
}

@(test)
find_node :: proc (t: ^testing.T) {
  ctx := setup(t);
  defer ygg.destroy_context(ctx);
  
  head_node := ygg.create_node(ctx, "head");
  link_node := ygg.create_node(ctx, "link", parent = &head_node);
  a_node    := ygg.create_node(ctx, "a", parent = &link_node);

  node_ptr := ygg.find_node(ctx, 2);
  testing.expect(t, node_ptr == nil, "A tag should not be found, since it is not attached to the tree");

  ygg.attach_node(ctx, head_node);
  ygg.attach_node(ctx, link_node);
  ygg.attach_node(ctx, a_node);
}

@(test)
max_depth :: proc (t: ^testing.T) {
  ctx := setup(t);
  defer ygg.destroy_context(ctx);

  max_node_depth: types.Id = types.Id(utils.get_max_number(types.Id));
  lvl_1: u16 = (max_node_depth / 16) + 1;

  for _ in 0..=lvl_1 - 1 {
    node := ygg.create_node(ctx, "head");
    ygg.attach_node(ctx, node);
  }

  testing.expect_value(t, ygg.get_node_depth(ctx.root, context.temp_allocator), lvl_1);

  lvl_2: u16 = lvl_1 * 4;   // 16k


  for _ in lvl_1..=lvl_2 - 1 {
    node  := ygg.create_node(ctx, "head");
    ygg.attach_node(ctx, node);
  }

  testing.expect_value(t, ygg.get_node_depth(ctx.root, context.temp_allocator), lvl_2);

  lvl_3: u16 = lvl_2 * 4;


  for _ in lvl_2..=lvl_3 - 1 {
    node := ygg.create_node(ctx, "head");
    ygg.attach_node(ctx, node);
  }

  testing.expect_value(t, ygg.get_node_depth(ctx.root, context.temp_allocator), lvl_3);
}

@(test)
id_overflow :: proc (t: ^testing.T) {
  ctx := setup(t);
  defer ygg.destroy_context(ctx);

  head  := ygg.create_node(ctx, tag = "head", id = 65_536);
  title := ygg.create_node(ctx, tag = "title", parent = &head);
  link  := ygg.create_node(ctx, tag = "link", parent = &head);

  testing.expect(t, head.id == 0, "Expected node id to overflow back to 0");

  ygg.attach_node(ctx, head);
  ygg.attach_node(ctx, title);
  ygg.attach_node(ctx, link);

  testing.expect(t, ctx.root.tag == "head", "Expected head to now be root due to overflow");
  testing.expect_value(t, ygg.get_node_depth(ctx.root, context.temp_allocator), 1);
}

//@(test)
//retained :: proc (t: ^testing.T) {
//  ex.hello_retained();
//}

@(test)
immediate :: proc (t: ^testing.T) {
  ex.hello_immediate();
}
