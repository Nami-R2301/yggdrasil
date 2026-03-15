package utils

import fmt "core:fmt"
import strings "core:strings"

import stb_font "vendor:stb/easy_font"

import types "../types"
import strconv "core:strconv"

into_str :: proc {
	into_str_bool,
	into_str_option,
	into_str_node,
	into_str_buffer,
	into_str_enum,
	into_str_option_ref,
	into_str_ctx,
	into_str_any,
}

@(export, link_prefix = "ygg_utils_", require_results)
into_debug :: proc(value: any) -> types.LogLevel {
	switch type in value {
	case types.LogLevel:
		return type
	case u8:
		{
			switch type {
			case 0:
				return types.LogLevel.None
			case 1:
				return types.LogLevel.Normal
			case 2:
				return types.LogLevel.Verbose
			case:
				return types.LogLevel.Everything
			}
		}
	case string:
		{
			switch type {
			case "",
			     "0",
			     "-",
			     "nil",
			     "null",
			     "n",
			     "N",
			     "no",
			     "NO",
			     "false",
			     "False",
			     "FALSE",
			     "none",
			     "None",
			     "NONE":
				return types.LogLevel.None
			case "1",
			     "v",
			     "y",
			     "yes",
			     "Yes",
			     "YES",
			     "true",
			     "True",
			     "TRUE",
			     "normal",
			     "Normal",
			     "NORMAL":
				return types.LogLevel.Normal
			case "2", "vv", "verbose", "Verbose", "VERBOSE":
				return types.LogLevel.Verbose
			case "3", "vvv", "everything", "Everything", "EVERYTHING":
				return types.LogLevel.Everything
			case:
				return types.LogLevel.Normal

			}
		}
	case:
		return types.LogLevel.Normal
	}
}

@(export, link_prefix = "ygg_utils_", require_results)
into_bool :: proc(value: any) -> bool {
	switch &v in value {
	case bool:
		return v
	case string:
		{
			switch v {
			case "",
			     "0",
			     "-",
			     "nil",
			     "null",
			     "n",
			     "N",
			     "no",
			     "NO",
			     "false",
			     "False",
			     "FALSE",
			     "none",
			     "None",
			     "NONE":
				return false
			case "1", "yes", "Yes", "YES", "y", "Y", "true", "True", "TRUE":
				return true
			case:
				return false
			}
		}
	case int:
		return v >= 0
	case types.Node:
		return v.tag != "N/A" && v.parent != nil
	case Maybe(int):
		return is_some(v) && unwrap(v) >= 0
	case Maybe(bool):
		return is_some(v) && unwrap(v)
	case rawptr:
		return v != nil
	case:
		return false
	}
}

@(export, link_prefix = "ygg_utils_", require_results)
into_str_any :: proc(value: any) -> string {
	switch v in value {
	case string:
		return v
	case Maybe(types.Node):
		return into_str_option(types.Node, v)
	case Maybe(^types.Node):
		return into_str_option_ref(types.Node, v)
	case types.LogLevel:
		return into_str_enum(v)
	case ^types.Node:
		return into_str_node(v)
	case ^types.Buffer:
		return into_str_buffer(v)
	case ^types.Context:
		return into_str_ctx(v)
	case:
		return "Unimplemented"
	}
}

@(export, link_prefix = "ygg_utils_", require_results)
into_str_bool :: proc(value: bool) -> string {
	return value ? "true" : "false"
}

@(export, link_prefix = "ygg_utils_", require_results)
into_str_option :: proc($T: typeid, opt: Maybe(T), indent: string = "  ") -> string {
	#partial switch &value in opt {
	case T:
		{
			switch &value {
			case nil:
				return "None"
			case:
				if T == types.Node {
					return into_str_node(&value, indent)
				}

				return "None"
			}
		}
	case nil:
		return "None"
	}

	return "None"
}

@(export, link_prefix = "ygg_utils_", require_results)
into_str_option_ref :: proc($T: typeid, opt: Maybe(^T), indent: string = "  ") -> string {
	#partial switch value in opt {
	case ^T:
		{
			switch value {
			case nil:
				return "None"
			case:
				if T == types.Node {
					return into_str_node(value, indent)
				}

				return "None"
			}
		}
	case nil:
		return "None"
	}

	return "None"
}

@(export, link_prefix = "ygg_utils_", require_results)
into_str_node :: proc(node: ^types.Node, indent: string = "  ") -> string {
	if node == nil {
		return "nil (0x0)"
	}

	parent_tag := node.parent != nil ? node.parent.tag : "nil"
	return fmt.tprintf(
		"{{\n{0}  [{}] -> {{\n{0}  Parent: {} (%p),\n{0}  id: {}\n{0}}}",
		indent,
		node.tag,
		parent_tag,
		node.parent,
		node.id,
	)
}

@(export, link_prefix = "ygg_utils_", require_results)
into_str_enum :: proc(debug: types.LogLevel, indent: string = "  ") -> string {
	str, _ := fmt.enum_value_to_string(debug)
	return str
}

@(export, link_prefix = "ygg_utils_", require_results)
into_str_buffer :: proc(buffer: ^types.Buffer, indent: string = "  ") -> string {
	if buffer == nil {
		return "nil (0x0)"
	}

	return fmt.tprintf(
		"{{\n{0}   Id: {},\n{0}   Type: {},\n{0}   Count: {},\n{0}   Length: {},\n{0}   Capacity: {}\n{0} }}",
		indent,
		buffer.id,
		buffer.type,
		buffer.count,
		buffer.length,
		buffer.capacity,
	)
}

// Try to prettify an object (preferably tree-like) in a JSON-like structure to pass onto 'printf()'.
//
// @param obj:    Object to deserialize
// @param indent: The amount of horizontal padding to indent any inner-elements.
@(export, link_prefix = "ygg_utils_", require_results)
into_str_ctx :: proc(ctx: ^types.Context, indent: string = "  ") -> string {
	inner_indent := strings.concatenate({indent, "  "}, context.temp_allocator)

	last_node: string = "nil"
	if ctx.last_node != nil {
		last_node = into_str(ctx.last_node, inner_indent)
	}

	new_str := fmt.tprintf(
		"Context: {{\n{0}  Debug Level: {},\n{0}  Root ptr: {}," +
		"\n{0}  Window ptr: ({}),\n{0}  Last Node ptr: {},\n{0}  Cursor: [{},{}],\n{0}}}",
		indent,
		into_str(ctx.log_level),
		into_str(ctx.root, inner_indent),
		ctx.window == nil ? nil : ctx.window,
		last_node,
		ctx.cursor[0],
		ctx.cursor[1],
	)

	return new_str
}

// Turn an array of vertices into an array of compatible quads for stb fonts. Used primarily to render text glyphs.
//
// @lifetime:           No allocations are made onto the heap - no freeing involved.
// @param vertices_ptr: A list of vertices to use to render the quad.
// @return              A single stb font quad.
@(export, link_prefix = "ygg_utils_", require_results)
into_quad :: proc(vertices_ptr: ^[5]types.Vertex) -> stb_font.Quad {
	if vertices_ptr == nil {
		return {}
	}

	tl: stb_font.Vertex = {
		v = vertices_ptr[0].position,
		c = {
			cast(u8)vertices_ptr[0].color.r,
			cast(u8)vertices_ptr[0].color.g,
			cast(u8)vertices_ptr[0].color.b,
			cast(u8)vertices_ptr[0].color.a,
		},
	}
	tr: stb_font.Vertex = {
		v = vertices_ptr[1].position,
		c = {
			cast(u8)vertices_ptr[1].color.r,
			cast(u8)vertices_ptr[1].color.g,
			cast(u8)vertices_ptr[1].color.b,
			cast(u8)vertices_ptr[1].color.a,
		},
	}
	br: stb_font.Vertex = {
		v = vertices_ptr[2].position,
		c = {
			cast(u8)vertices_ptr[2].color.r,
			cast(u8)vertices_ptr[2].color.g,
			cast(u8)vertices_ptr[2].color.b,
			cast(u8)vertices_ptr[2].color.a,
		},
	}
	bl: stb_font.Vertex = {
		v = vertices_ptr[4].position,
		c = {
			cast(u8)vertices_ptr[4].color.r,
			cast(u8)vertices_ptr[4].color.g,
			cast(u8)vertices_ptr[4].color.b,
			cast(u8)vertices_ptr[4].color.a,
		},
	}


	return stb_font.Quad{tl, tr, br, bl}
}

@(export, link_prefix = "ygg_utils_", require_results)
into_measure :: proc(measure_str: Maybe(string)) -> [2]u32 {
	default: [2]u32 = {50, 50}

	if is_none(measure_str) {
		return default
	}

	str := unwrap(measure_str)
	coords := strings.split(str, ",")

	if len(coords) == 0 {
		return default
	}

	x_trimmed := strings.trim(coords[0], " ")
	if strings.contains_any(str, "px") {
		// We are in pixel coord land - easy
		x_pixel, x_ok := strconv.parse_int(x_trimmed)
		if !x_ok {
			x_pixel = 0
		}

		y_trimmed := strings.trim(coords[1], " ")
		y_pixel, y_ok := strconv.parse_int(y_trimmed)
		if !y_ok {
			y_pixel = 0
		}

		return {u32(x_pixel), u32(y_pixel)}
	}

	x, x_ok := strconv.parse_int(x_trimmed)
	if !x_ok {
		x = 0
	}


	if len(coords) > 1 {
		y_trimmed := strings.trim(coords[1], " ")
		y, is_ok := strconv.parse_int(y_trimmed)
		if !is_ok {
			return {u32(x), 0}
		}

		return {u32(x), u32(y)}
	}

	return {u32(x), 0}
}

@(export, link_prefix = "ygg_utils_", require_results)
into_z_index :: proc(z_index_str: Maybe(string)) -> u16 {
	default: u16 = 0

	if is_none(z_index_str) {
		return default
	}

	z_str := unwrap(z_index_str)
	trimmed := strings.trim(z_str, " ")
	z, ok := strconv.parse_uint(trimmed)
	if !ok {
		return default
	}

	default = u16(z)
	return default
}

@(export, link_prefix = "ygg_utils_", require_results)
into_color :: proc(color_str: Maybe(string)) -> [4]f32 {
	default := [4]f32{1, 1, 1, 1}
	if is_none(color_str) {
		return default
	}

	color := unwrap(color_str)
	channels, err := strings.split(color, ",")
	if err != nil {
		return default
	}

	if len(channels) == 1 {
		// Maybe we are converting a hex value (0xXXXXXX)
		trimmed := strings.trim(color, " ")
		hex, ok := strconv.parse_int(trimmed)
		if ok {
			r := hex >> 24 & 0xFF
			g := hex >> 16 & 0xFF
			b := hex >> 8 & 0xFF
			a := hex & 0xFF

			// Normalize for stinky OpenGL
			norm_r := f32(r) / 256.0
			norm_g := f32(g) / 256.0
			norm_b := f32(b) / 256.0
			norm_a := f32(a) / 256.0
			return {norm_r, norm_g, norm_b, norm_a}
		}

		return default
	}

	fmt.printfln("Channels : {}", channels)
	for i in 0 ..< len(channels) {
		trimmed := strings.trim(channels[i], " ")
		float, ok := strconv.parse_f32(trimmed)
		if !ok do continue

		default[i] = float
	}

	return default
}
