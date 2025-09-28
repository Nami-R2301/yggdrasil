#+feature dynamic-literals
package tests;

import "core:testing";
import "core:fmt";

import ygg "../src";
import "yggdrasil:types";
import "yggdrasil:utils";

config : map[string]types.Option(string) = {
  "test_mode" =  utils.some("true"),
  "headless"  =  utils.some("true"),
  "log_level" =  utils.some("v")
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
  error2, node := _create_node(&ctx, "root");
  assert(error2 == ContextError.None, "Error creating root node");
  error = _attach_node(&ctx, node);
  assert(error == ContextError.None, "Error attaching root node");

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

  _, first  := _create_node(&ctx, "head", utils.some(1));
  _, second := _create_node(&ctx, "head2", utils.some(1));

  error := _attach_node(&ctx, first);
  error = _attach_node(&ctx, second);

  testing.expect_value(t, error, ContextError.None);
}

@(test)
find_node :: proc (t: ^testing.T) {
  using types;
  using ygg;
  using utils;
  
  ctx := setup(t);
  defer cleanup(&ctx);
  
  _, head  := _create_node(&ctx, "head");
  _, link  := _create_node(&ctx, "link", parent = &head);
  _, a     := _create_node(&ctx, "a", parent = &link);

  node_ptr := _find_node(&ctx, 2);
  testing.expect(t, node_ptr == nil, "A tag should not be found, since it is not attached to the tree");

  error := _attach_node(&ctx, head);
  testing.expect(t, error == ContextError.None, "Error attaching <head> node");
  
  error = _attach_node(&ctx, link);
  testing.expect(t, error == ContextError.None, "Error attaching <link> node");
  
  error = _attach_node(&ctx, a);
  testing.expect(t, error == ContextError.None, "Error attaching <a> node");
}

@(test)
max_depth :: proc (t: ^testing.T) {
  using types;
  using ygg;

  ctx := setup(t);
  defer cleanup(&ctx);

  lvl_1: u16 = 4096;

  for _ in 0..=lvl_1 - 1 {
    _, node  := _create_node(&ctx, "head");
    error := _attach_node(&ctx, node);
    assert(error == ContextError.None, "Error attaching node");
  }

  testing.expect_value(t, _get_node_depth(ctx.root), lvl_1);

  lvl_2: u16 = lvl_1 * 4;   // 16k


  for _ in lvl_1..=lvl_2 - 1 {
    _, node  := _create_node(&ctx, "head");
    error := _attach_node(&ctx, node);
    assert(error == ContextError.None, "Error attaching node");
  }


  testing.expect_value(t, _get_node_depth(ctx.root), lvl_2);

  lvl_3: types.Id = 65535;  // u16 limit


  for _ in lvl_2..=lvl_3 - 1 {
    _, node  := _create_node(&ctx, "head");
    error := _attach_node(&ctx, node);
    assert(error == ContextError.None, "Error attaching node");
  }

  testing.expect_value(t, _get_node_depth(ctx.root), lvl_3);
}

@(test)
max_encoding_reached :: proc (t: ^testing.T) {
  using types;

  ctx := setup(t);
  defer cleanup(&ctx);

  error_encoding, head  := ygg._create_node(&ctx, tag = "head", id = utils.some(65_536));
  testing.expect(t, error_encoding == ContextError.MaxIdReached, "Expected to fail when detecting ID oveflow");

}
