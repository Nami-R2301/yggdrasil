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

  node, error := rt.create_node("root");
  node_err    := rt.attach_node(node);
  assert(node_err == NodeError.None, "Error attaching root node");
  return ctx;
}


@(test)
create_duplicate :: proc (t: ^testing.T) {
  using types;

  ctx := setup(t);
  context.user_ptr = &ctx;

  defer {
    error := rt.destroy_context();
    assert(error == types.ContextError.None, "Error during test cleanup");
  }

  first,  err1  := rt.create_node("head", utils.some(1));
  testing.expect(t, err1 == ContextError.None, "Error creating node");

  second, err2  := rt.create_node("head2", utils.some(1));
  testing.expect(t, err1 == ContextError.None, "Error creating node");


  err := rt.attach_node(first);
  testing.expect(t, err == NodeError.None, "Error attaching first node");

  err  = rt.attach_node(second);
  testing.expect(t, err == NodeError.None, "Error attaching second node");
}

@(test)
find_node :: proc (t: ^testing.T) {
  using types;
  using utils;

  ctx := setup(t);
  context.user_ptr = &ctx;

  defer {
    error := rt.destroy_context();
    assert(error == types.ContextError.None, "Error during test cleanup");
  }
  
  head_node, err1  := rt.create_node("head");
  testing.expect(t, err1 == ContextError.None, "Error creating node");

  link_node, err2  := rt.create_node("link", parent = &head_node);
  testing.expect(t, err2 == ContextError.None, "Error creating node");

  a_node,    err3  := rt.create_node("a", parent = &link_node);
  testing.expect(t, err1 == ContextError.None, "Error creating node");

  node_ptr := ygg.find_node(2);
  testing.expect(t, node_ptr == nil, "A tag should not be found, since it is not attached to the tree");

  err := rt.attach_node(head_node);
  testing.expect(t, err == NodeError.None, "Error attaching <head> node");

  err  = rt.attach_node(link_node);
  testing.expect(t, err == NodeError.None, "Error attaching <link> node");

  err  = rt.attach_node(a_node);
  testing.expect(t, err == NodeError.None, "Error attaching <a> node");
}

@(test)
max_depth :: proc (t: ^testing.T) {
  using types;
  using utils;

  ctx := setup(t);
  context.user_ptr = &ctx;

  defer {
    error := rt.destroy_context();
    assert(error == types.ContextError.None, "Error during test cleanup");
  }

  max_node_depth: Id = Id(_get_max_number(Id));
  lvl_1: u16 = (max_node_depth / 16) + 1;

  for _ in 0..=lvl_1 - 1 {
    node, err1  := rt.create_node("head");
    testing.expect(t, err1 == ContextError.None, "Error creating node");

    error      := rt.attach_node(node);
    testing.expect_value(t, error, NodeError.None);
  }

  testing.expect_value(t, ygg.get_node_depth(ctx.root), lvl_1);

  lvl_2: u16 = lvl_1 * 4;   // 16k


  for _ in lvl_1..=lvl_2 - 1 {
    node, err1  := rt.create_node("head");
    testing.expect(t, err1 == ContextError.None, "Error creating node");

    error      := rt.attach_node(node);
    testing.expect_value(t, error, NodeError.None);
  }

  testing.expect_value(t, ygg.get_node_depth(ctx.root), lvl_2);

  lvl_3: u16 = lvl_2 * 4;


  for _ in lvl_2..=lvl_3 - 1 {
    node, err1  := rt.create_node("head");
    testing.expect(t, err1 == ContextError.None, "Error creating node");

    error := rt.attach_node(node);
    testing.expect(t, error == NodeError.None, "Error attaching node");
  }

  testing.expect_value(t, ygg.get_node_depth(ctx.root), lvl_3);
}

@(test)
id_overflow :: proc (t: ^testing.T) {
  using types;

  ctx := setup(t);
  context.user_ptr = &ctx;

  defer {
    error := rt.destroy_context();
    assert(error == types.ContextError.None, "Error during test cleanup");
  }

  head,  err1  := rt.create_node(tag = "head", id = utils.some(65_536));
  testing.expect(t, err1 == ContextError.None, "Error creating node");

  title, err2  := rt.create_node(tag = "title", parent = &head);
  testing.expect(t, err2 == ContextError.None, "Error creating node");

  link,  err3  := rt.create_node(tag = "link", parent = &head);
  testing.expect(t, err3 == ContextError.None, "Error creating node");

  testing.expect(t, head.id == 0, "Expected node id to overflow back to 0");

  err := rt.attach_node(head);
  err  = rt.attach_node(title);
  err  = rt.attach_node(link);
  testing.expect(t, ctx.root.tag == "head", "Expected head to now be root due to overflow");
  testing.expect_value(t, ygg.get_node_depth(ctx.root), 1);
}
