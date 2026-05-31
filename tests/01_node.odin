#+feature dynamic-literals
package tests

import "core:math"
import testing "core:testing"

import ex "../examples"
import ygg "../src"
import types "../src/types"
import utils "../src/utils"
import fmt "core:fmt"

setup :: proc(t: ^testing.T, config: map[string]string) -> ^types.Context {
	c := config
	ctx := ygg.create_context(config = &c)
	node := ygg.create_node(ctx, "root")
	ygg.attach_node(ctx, node)
	return ctx
}

config: map[string]string = {
	"test_mode" = "true",
	"headless"  = "true",
	"log_level" = "v",
}

@(test)
create_duplicate :: proc(t: ^testing.T) {
	ctx := setup(t, config)
	defer ygg.destroy_context(ctx)

	first := ygg.create_node(ctx, "head", 1, parent = ctx.root)
	second := ygg.create_node(ctx, "head2", 1, parent = ctx.root)

	ygg.attach_node(ctx, first)
	ygg.attach_node(ctx, second)
}

@(test)
find_node :: proc(t: ^testing.T) {
	ctx := setup(t, config)
	defer ygg.destroy_context(ctx)

	head_node := ygg.create_node(ctx, "head")
	link_node := ygg.create_node(ctx, "link", parent = &head_node)
	a_node := ygg.create_node(ctx, "a", parent = &link_node)

	node_ptr := ygg.find_node(ctx, 2)
	testing.expect(
		t,
		node_ptr == nil,
		"A tag should not be found, since it is not attached to the tree",
	)

	ygg.attach_node(ctx, head_node)
	ygg.attach_node(ctx, link_node)
	ygg.attach_node(ctx, a_node)
}

@(test)
max_depth :: proc(t: ^testing.T) {
	ctx := setup(t, config)
	defer ygg.destroy_context(ctx)

	// Test deep nesting - build a chain where each node is a child of the previous
	lvl_1: u16 = 1 << 8
	lvl_2: u16 = 1 << 12
	lvl_3: u16 = (1 << 16) - 1

	last_parent := ctx.root
	for i in 0 ..< lvl_1 {
		node := ygg.create_node(ctx, "head", parent = last_parent)
		ygg.attach_node(ctx, node)
		// Access the child directly from parent's children map (it's a value copy, safe to take address here)
		last_parent = &last_parent.children[node.id]
	}

	testing.expect_value(t, ygg.get_node_depth(ctx.root, context.temp_allocator), lvl_1)

	for i in lvl_1 ..< lvl_2 {
		node := ygg.create_node(ctx, "head", parent = last_parent)
		ygg.attach_node(ctx, node)
		last_parent = &last_parent.children[node.id]
	}

	testing.expect_value(t, ygg.get_node_depth(ctx.root, context.temp_allocator), lvl_2)

	for i in lvl_2 ..< lvl_3 {
		node := ygg.create_node(ctx, "head", parent = last_parent)
		ygg.attach_node(ctx, node)
		last_parent = &last_parent.children[node.id]
	}

	testing.expect_value(t, ygg.get_node_depth(ctx.root, context.temp_allocator), lvl_3)
}

@(test)
id_overflow :: proc(t: ^testing.T) {
	ctx := setup(t, config)
	defer ygg.destroy_context(ctx)

	head := ygg.create_node(ctx, tag = "head", id = 65_536)
	title := ygg.create_node(ctx, tag = "title", parent = &head)
	link := ygg.create_node(ctx, tag = "link", parent = &head)

	testing.expect(t, head.id == 0, "Expected node id to overflow back to 0")

	ygg.attach_node(ctx, head)
	ygg.attach_node(ctx, title)
	ygg.attach_node(ctx, link)

	testing.expect(t, ctx.root.tag == "head", "Expected head to now be root due to overflow")
	testing.expect_value(t, ygg.get_node_depth(ctx.root, context.temp_allocator), 1)
}

//@(test)
//retained :: proc (t: ^testing.T) {
//  ex.hello_retained();
//}

// @(test)
// immediate :: proc(t: ^testing.T) {
// 	ex.hello_immediate()
// }
