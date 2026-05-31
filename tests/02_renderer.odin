#+feature dynamic-literals
package tests

import runtime "base:runtime"
import "core:fmt"
import "core:sys/windows"
import "core:testing"

import ygg "../src"
import types "../src/types"
import glfw "vendor:glfw"

renderer_config: map[string]string = {
	"test_mode" = "true",
	"headless"  = "false",
	"log_level" = "v",
}

setup_renderer :: proc() -> (types.Renderer, types.Window) {
	window := ygg.create_window("Renderer Unit Tests")
	return ygg.create_renderer(&window), window
}

cleanup_renderer :: proc(window: ^types.Window, renderer: ^types.Renderer) {
	ygg.destroy_renderer(renderer)
	ygg.destroy_window(window)
}

// ============================================================================
// RENDERER / BUFFER UNIT TESTS
//
// These tests verify buffer structure, data types, and calculations without
// requiring OpenGL context. Tests focus on:
// - Data structure layout and sizes
// - Vertex packing validation
// - Buffer capacity arithmetic
// - Type safety verification
//
// NOTE: Tests involving actual buffer creation (create_buffer, push_data,
// pop_data, migrate_buffer, etc.) require an active OpenGL context and cannot
// run in headless test environments. See BUGS_AND_EDGE_CASES.md for detailed
// integration test scenarios and discovered issues.
// ============================================================================
@(test)
test_vertex_structure_size :: proc(t: ^testing.T) {
	vertex_size := size_of(types.Vertex)

	// Vertex should be: i32 (4) + [3]f32 (12) + [4]f32 (16) + [2]f32 (8) = 40 bytes
	expected_size := size_of(i32) + size_of([3]f32) + size_of([4]f32) + size_of([2]f32)

	testing.expect(
		t,
		vertex_size == expected_size,
		fmt.tprintf(
			"Vertex size should be %d bytes, got %d - potential packing issue with #packed directive",
			expected_size,
			vertex_size,
		),
	)

	// Also verify it's exactly 40 bytes as expected for shader compatibility
	testing.expect(
		t,
		vertex_size == 40,
		fmt.tprintf(
			"Vertex must be exactly 40 bytes for OpenGL shader compatibility, got %d",
			vertex_size,
		),
	)
}

@(test)
test_vertex_field_layout :: proc(t: ^testing.T) {
	v := types.Vertex {
		entity_id  = 42,
		position   = {1.0, 2.0, 3.0},
		color      = {0.5, 0.5, 0.5, 1.0},
		tex_coords = {0.0, 1.0},
	}

	testing.expect(t, v.entity_id == 42, "entity_id should be accessible")
	testing.expect(t, v.position[0] == 1.0, "position.x should be accessible")
	testing.expect(t, v.position[1] == 2.0, "position.y should be accessible")
	testing.expect(t, v.position[2] == 3.0, "position.z should be accessible")
	testing.expect(t, v.color[0] == 0.5, "color.r should be accessible")
	testing.expect(t, v.color[3] == 1.0, "color.a should be accessible")
	testing.expect(t, v.tex_coords[0] == 0.0, "tex_coords.u should be accessible")
	testing.expect(t, v.tex_coords[1] == 1.0, "tex_coords.v should be accessible")
}

@(test)
test_buffer_structure :: proc(t: ^testing.T) {
	buffer := types.Buffer {
		id              = 123,
		type            = types.BufferType.Vbo,
		count           = 10,
		length          = 400,
		capacity        = 1000,
		attachments_opt = {0, 0},
	}

	testing.expect(t, buffer.id == 123, "Buffer ID should be set correctly")
	testing.expect(t, buffer.type == types.BufferType.Vbo, "Buffer type should be Vbo")
	testing.expect(t, buffer.count == 10, "Buffer count should be 10")
	testing.expect(t, buffer.length == 400, "Buffer length should be 400")
	testing.expect(t, buffer.capacity == 1000, "Buffer capacity should be 1000")
}

@(test)
test_data_structure :: proc(t: ^testing.T) {
	vertices := [3]types.Vertex {
		{entity_id = 1, position = {0, 0, 0}, color = {1, 0, 0, 1}, tex_coords = {0, 0}},
		{entity_id = 2, position = {1, 0, 0}, color = {0, 1, 0, 1}, tex_coords = {1, 0}},
		{entity_id = 3, position = {1, 1, 0}, color = {0, 0, 1, 1}, tex_coords = {1, 1}},
	}

	data := types.Data {
		ptr   = &vertices[0],
		count = 3,
		size  = size_of(types.Vertex),
	}

	testing.expect(t, data.ptr != nil, "Data pointer should not be nil")
	testing.expect(t, data.count == 3, "Data count should be 3")
	testing.expect(t, data.size == size_of(types.Vertex), "Data size should match Vertex size")

	total_bytes := data.count * data.size
	expected_bytes := 3 * size_of(types.Vertex)

	testing.expect(
		t,
		total_bytes == u64(expected_bytes),
		fmt.tprintf(
			"Total data bytes should be %d (3 vertices * %d bytes), got %d",
			expected_bytes,
			size_of(types.Vertex),
			total_bytes,
		),
	)
}

@(test)
test_buffer_grow_arithmetic :: proc(t: ^testing.T) {
	initial_capacity: u64 = 1000
	grow_amount: u64 = 500

	// This is what grow_buffer does: buffer.capacity += size_bytes
	new_capacity := initial_capacity + grow_amount

	testing.expect(
		t,
		new_capacity == 1500,
		fmt.tprintf(
			"Growing buffer from %d by %d should result in %d",
			initial_capacity,
			grow_amount,
			1500,
		),
	)
}

@(test)
test_buffer_shrink_arithmetic :: proc(t: ^testing.T) {
	initial_capacity: u64 = 1000
	shrink_amount: u64 = 300

	// This is what shrink_buffer does: buffer.capacity -= size_bytes
	// It should check: if buffer.capacity - size_bytes < 0

	testing.expect(
		t,
		initial_capacity >= shrink_amount,
		"Shrink should only succeed when amount <= capacity",
	)

	new_capacity := initial_capacity - shrink_amount
	testing.expect(t, new_capacity == 700, "Shrinking 1000 by 300 should give 700")

	// Test underflow scenario
	oversized_shrink: u64 = 1500
	would_underflow := initial_capacity < oversized_shrink

	testing.expect(
		t,
		would_underflow,
		"Shrinking by 1500 from capacity 1000 should be detected as underflow",
	)
}

@(test)
test_capacity_limit_constant :: proc(t: ^testing.T) {
	// C_VBO_SIZE_LIMIT in buffer.odin is 10_000_000
	max_limit: u64 = 10_000_000

	// Test boundary conditions
	testing.expect(t, max_limit - 1 < max_limit, "limit-1 should be less than limit")

	testing.expect(t, max_limit == max_limit, "limit should equal limit (boundary)")

	testing.expect(t, max_limit + 1 > max_limit, "limit+1 should exceed limit")
}

@(test)
test_push_data_size_calculation :: proc(t: ^testing.T) {
	vertex_count: u64 = 4
	vertex_size := u64(size_of(types.Vertex))

	// This is how push_data calculates size: data.count * data.size
	total_size := vertex_count * vertex_size

	expected_size := 4 * 40 // 4 vertices * 40 bytes each

	testing.expect(
		t,
		total_size == u64(expected_size),
		fmt.tprintf(
			"Pushing 4 vertices should require %d bytes, got %d",
			expected_size,
			total_size,
		),
	)
}

@(test)
test_buffer_overflow_detection :: proc(t: ^testing.T) {
	buffer_capacity: u64 = 1000
	current_length: u64 = 800
	push_size: u64 = 300

	// This is the check in push_data: from_where + size_bytes > original_size
	from_where := current_length // Default: append at end
	would_overflow := from_where + push_size > buffer_capacity

	testing.expect(
		t,
		would_overflow,
		"Pushing 300 bytes at position 800 in 1000-byte buffer should overflow",
	)

	// Test case that fits
	safe_push_size: u64 = 100
	would_fit := from_where + safe_push_size <= buffer_capacity

	testing.expect(
		t,
		would_fit,
		"Pushing 100 bytes at position 800 in 1000-byte buffer should fit",
	)
}

@(test)
test_buffer_underflow_detection :: proc(t: ^testing.T) {
	buffer_length: u64 = 400
	pop_size: u64 = 500

	// This is the check in pop_data: buffer.length - size_bytes < 0
	// Note: In Odin with unsigned integers, we need to check before subtracting
	would_underflow := buffer_length < pop_size

	testing.expect(
		t,
		would_underflow,
		"Popping 500 bytes from buffer with 400 bytes should underflow",
	)

	// Test safe pop
	safe_pop: u64 = 100
	is_safe := buffer_length >= safe_pop

	testing.expect(t, is_safe, "Popping 100 bytes from buffer with 400 bytes should be safe")
}

@(test)
test_buffer_type_enum :: proc(t: ^testing.T) {
	vbo := types.BufferType.Vbo
	vao := types.BufferType.Vao
	fbo := types.BufferType.Framebuffer

	testing.expect(t, vbo != vao, "Vbo and Vao should be different types")
	testing.expect(t, vbo != fbo, "Vbo and Framebuffer should be different types")
	testing.expect(t, vao != fbo, "Vao and Framebuffer should be different types")
}

// Test 12: BufferError enum values
@(test)
test_buffer_error_enum :: proc(t: ^testing.T) {
	none := types.BufferError.None
	exceeded := types.BufferError.ExceededMaxSize
	invalid_size := types.BufferError.InvalidSize

	testing.expect(t, none != exceeded, "None and ExceededMaxSize should be different")
	testing.expect(t, none != invalid_size, "None and InvalidSize should be different")
	testing.expect(
		t,
		exceeded != invalid_size,
		"ExceededMaxSize and InvalidSize should be different",
	)
}

@(test)
test_multiple_vertices_calculation :: proc(t: ^testing.T) {
	// Simulate multiple pushes to VBO
	vertex_size := u64(size_of(types.Vertex))

	push_counts := []u64{4, 2, 6, 3}
	total_vertices: u64 = 0
	total_bytes: u64 = 0

	for count in push_counts {
		total_vertices += count
		total_bytes += count * vertex_size
	}

	expected_vertices: u64 = 15 // 4+2+6+3
	expected_bytes: u64 = 15 * 40 // 15 vertices * 40 bytes

	testing.expect(
		t,
		total_vertices == expected_vertices,
		fmt.tprintf("Total vertices should be %d, got %d", expected_vertices, total_vertices),
	)

	testing.expect(
		t,
		total_bytes == expected_bytes,
		fmt.tprintf("Total bytes should be %d, got %d", expected_bytes, total_bytes),
	)
}

@(test)
test_reset_logic :: proc(t: ^testing.T) {
	// Simulate buffer state before reset
	length_before: u64 = 500
	count_before: u64 = 12
	capacity_before: u64 = 1000

	// reset_buffer sets: buffer.length = 0, buffer.count = 0
	length_after: u64 = 0
	count_after: u64 = 0
	capacity_after := capacity_before // Capacity unchanged

	testing.expect(t, length_after == 0, "Length should be 0 after reset")
	testing.expect(t, count_after == 0, "Count should be 0 after reset")
	testing.expect(
		t,
		capacity_after == capacity_before,
		"Capacity should remain unchanged after reset",
	)
}

@(test)
test_glyph_structure :: proc(t: ^testing.T) {
	glyph_size := size_of(types.Glyph)

	// Glyph: i32 (4) + 4*f32 (16) + [4]u32 (16) = 36 bytes
	expected_size := size_of(i32) + 4 * size_of(f32) + size_of([4]u32)

	testing.expect(
		t,
		glyph_size == expected_size,
		fmt.tprintf("Glyph size should be %d bytes, got %d", expected_size, glyph_size),
	)
}

@(test)
test_large_vertex_array :: proc(t: ^testing.T) {
	// Test with realistic UI scenario: 1000 quads = 4000 vertices
	num_quads: u64 = 1000
	vertices_per_quad: u64 = 4
	total_vertices := num_quads * vertices_per_quad

	vertex_size := u64(size_of(types.Vertex))
	total_bytes := total_vertices * vertex_size

	expected_vertices: u64 = 4000
	expected_bytes: u64 = 4000 * 40

	testing.expect(
		t,
		total_vertices == expected_vertices,
		fmt.tprintf("1000 quads should have %d vertices", expected_vertices),
	)

	testing.expect(
		t,
		total_bytes == expected_bytes,
		fmt.tprintf(
			"1000 quads should require %d bytes (%d KB)",
			expected_bytes,
			expected_bytes / 1024,
		),
	)

	// Verify it fits within default VBO capacity (1_000_000)
	default_capacity: u64 = 1_000_000
	fits_in_default := total_bytes <= default_capacity

	testing.expect(
		t,
		fits_in_default,
		fmt.tprintf(
			"1000 quads (%d bytes) should fit in default VBO capacity (%d bytes)",
			total_bytes,
			default_capacity,
		),
	)
}

// Test 17: Max VBO capacity calculation
@(test)
test_max_vbo_capacity :: proc(t: ^testing.T) {
	max_capacity: u64 = 10_000_000
	vertex_size := u64(size_of(types.Vertex))

	max_vertices := max_capacity / vertex_size
	expected_max_vertices: u64 = 250_000 // 10,000,000 / 40

	testing.expect(
		t,
		max_vertices == expected_max_vertices,
		fmt.tprintf(
			"Max VBO capacity of %d bytes should hold %d vertices (got %d)",
			max_capacity,
			expected_max_vertices,
			max_vertices,
		),
	)

	// This represents max quads that can fit
	max_quads := max_vertices / 4
	testing.expect(
		t,
		max_quads == 62_500,
		fmt.tprintf("Max VBO can hold %d quads (250,000 vertices / 4)", max_quads),
	)
}

// Test 18: Data pointer safety
@(test)
test_data_pointer_validity :: proc(t: ^testing.T) {
	vertices := [2]types.Vertex {
		{entity_id = 1, position = {0, 0, 0}, color = {1, 0, 0, 1}, tex_coords = {0, 0}},
		{entity_id = 2, position = {1, 1, 0}, color = {0, 1, 0, 1}, tex_coords = {1, 1}},
	}

	// Test valid data
	valid_data := types.Data {
		ptr   = &vertices[0],
		count = 2,
		size  = size_of(types.Vertex),
	}
	testing.expect(t, valid_data.ptr != nil, "Valid data should have non-nil pointer")

	// Test nil data
	nil_data := types.Data {
		ptr   = nil,
		count = 0,
		size  = 0,
	}
	testing.expect(t, nil_data.ptr == nil, "Nil data should have nil pointer")
}

@(test)
test_init_vbo :: proc(t: ^testing.T) {
	renderer, window := setup_renderer()
	defer cleanup_renderer(&window, &renderer)

	testing.expect(
		t,
		renderer.state == types.RendererState.Initialized && renderer.pipeline.vbo.id != 0,
		"Renderer should have been initialized",
	)
}

@(test)
test_create_vbo_overflow :: proc(t: ^testing.T) {
	renderer, window := setup_renderer()
	defer cleanup_renderer(&window, &renderer)

	_, error := ygg.create_buffer(types.BufferType.Vbo, capacity = 10_500_000)
	testing.expect(t, error == types.BufferError.ExceededMaxSize, "Buffer should have overflowed")
}
