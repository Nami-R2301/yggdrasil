#+feature dynamic-literals
package tests;

import "core:testing";
import "core:fmt";

import ygg "../src";
import "yggdrasil:types";
import "yggdrasil:utils";

config : map[string]types.Option(string) = {
  "test_mode" =    utils.some("on"),
  "debug_level" =  utils.some("None")
};

setup :: proc (t: ^testing.T) -> types.Context {
  using types;
  using ygg;
  using utils;

  error, ctx_opt := _create_context(config = config);
  if error != ContextError.None {
    fmt.eprintln("[ERR]:\t| Cannot create context: {}", error);
    testing.fail_now(t, "Cannot create context");
  }
  
  ctx := unwrap(ctx_opt);
  node := _create_node(&ctx, 0, "root");
  error = _attach_node(&ctx, node);
  assert(error == ContextError.None, "Error creating context");

  if error != ContextError.None {
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

  first  := _create_node(&ctx, 1, "head");
  second := _create_node(&ctx, 1, "head2");

  error := _attach_node(&ctx, first);
  assert(error == ContextError.None, "Error attaching first node");
  error = _attach_node(&ctx, second);
  assert(error == ContextError.None, "Error attaching second node");
  
  testing.expect_value(t, error, ContextError.DuplicateId);
}

@(test)
find_node :: proc (t: ^testing.T) {
  using types;
  using ygg;
  using utils;
  
  ctx := setup(t);
  defer cleanup(&ctx);
  
  head  := _create_node(&ctx, 1, "head");
  link := _create_node(&ctx, 2, "link", &head);
  a := _create_node(&ctx, 3, "a", &link);

  node_opt := _find_node(&ctx, 3);
  testing.expect(t, !is_some(node_opt));

  error := _attach_node(&ctx, head);
  assert(error == ContextError.None, "Error attaching <head> node");
  
  error = _attach_node(&ctx, link);
  assert(error == ContextError.None, "Error attaching <link> node");
  
  error = _attach_node(&ctx, a);
  assert(error == ContextError.None, "Error attaching <a> node");
}

@(test)
max_depth :: proc (t: ^testing.T) {
  using types;
  using ygg;

  ctx := setup(t); 
  defer cleanup(&ctx);

  lvl_1: u16 = 4096;

  for index in 0..=lvl_1 - 1 {
    node  := _create_node(&ctx, index, "head");
    error := _attach_node(&ctx, node);
    assert(error == ContextError.None, "Error attaching node");
  }

  testing.expect_value(t, _get_tree_depth(ctx.root), lvl_1);

  lvl_2: u16 = lvl_1 * 4;   // 16k
  

  for index in lvl_1..=lvl_2 - 1 {
    node  := _create_node(&ctx, index, "head");
    error := _attach_node(&ctx, node);
    assert(error == ContextError.None, "Error attaching node");
  }


  testing.expect_value(t, _get_tree_depth(ctx.root), lvl_2);

  lvl_3: u16 = 65535;  // 6.4m


  for index in lvl_2..=lvl_3 - 1 {
    node  := _create_node(&ctx, index, "head");
    error := _attach_node(&ctx, node);
    assert(error == ContextError.None, "Error attaching node");
  }

  testing.expect_value(t, _get_tree_depth(ctx.root), lvl_3);
}
