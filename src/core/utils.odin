package core;

import "core:fmt";
import "core:strings";
import "vendor:glfw";

to_str_option :: proc (opt: Option($T), indent: string = "\t") -> string {
  #partial switch &value in opt {
    case T:           return to_str_node(&value, indent);
    case nil:         return "None";
  }

  return "None";
}

to_str_option_ref :: proc (opt: Option(^$T), indent: string = "\t") -> string {
  #partial switch value in opt {
    case T:           return to_str_node(value, indent);
    case rawptr:      return "None";
    case nil:         return "None";
  }

  return "None";
}

to_str_node :: proc (node: ^Node, indent: string = "\t") -> string {
  if node == nil {
    return "nil";
  }
  
  string_builder: strings.Builder = {};
  parent := node.parent != nil ? node.parent.tag : "nil";
  return fmt.sbprintf(&string_builder, "  [{1}] -> {{\n{0}  Parent: {2},\n{0}  id: {3}\n{0}}}", 
    indent, node.tag, parent, node.id);
}

to_str_enum :: proc (debug: DebugLevel, indent: string = "\t") -> string {
  str, _ := fmt.enum_value_to_string(debug); 
  return str;
}

// Try to prettify an object (preferably tree-like) in a JSON-like structure to pass onto 'printf()'.
//
// @param obj:    Object to deserialize
// @param indent: The amount of horizontal padding to indent any inner-elements.
to_str :: proc (ctx: Context, indent: string = "\t    ") -> string {
  string_builder: strings.Builder = {};

  return fmt.sbprintf(&string_builder, "{0}Context: {{\n{0}  Debug Level: {1},\n{0}  Root: {{\n{0}{2}\n{0}}},\n{0}  Window: {3}," +
      "\n{0}  Last Node: {{\n{0}{4}\n{0}}},\n{0}  Cursor: [{5},{6}],\n{0}}}", indent, to_str_enum(ctx.debug_level),
      to_str_node(ctx.root, "\t\t  "), ctx.window, to_str_option(ctx.last_node, "\t\t  "), ctx.cursor[0], ctx.cursor[1]);
}
