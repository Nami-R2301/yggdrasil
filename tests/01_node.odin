package tests;

import "core:testing";
import "../src/core";

@(test)
create_duplicate :: proc (t: ^testing.T) {
  ctx := core.create_context();

  _, first  := core.create_node(&ctx, 1, "head", core.none(core.Node));
  error, second := core.create_node(&ctx, 1, "head2", core.none(core.Node));
  
  testing.expect_value(t, error, core.Error.DuplicateId);
}
