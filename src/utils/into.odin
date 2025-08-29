package utils;

import "core:strconv";
import "core:strings";
import "core:fmt";

import "../types";

into_debug :: proc (value: any) -> types.LogLevel {
  switch type in value {
    case types.LogLevel: 
      return type;
    case u8: {
      switch type {
        case 0: return types.LogLevel.None;
        case 1: return types.LogLevel.Normal;
        case 2: return types.LogLevel.Verbose;
        case:   return types.LogLevel.Everything;
      }
    }
    case string: {
      switch type {
        case "", "0", "-", "nil", "null", "n", "N", "no", "NO", "false", "False", "FALSE", "none", "None", "NONE": 
          return types.LogLevel.None;
        case "1", "v", "y", "yes", "Yes", "YES", "true", "True", "TRUE", "normal", "Normal", "NORMAL":
          return types.LogLevel.Normal;
        case "2", "vv", "verbose", "Verbose", "VERBOSE":
          return types.LogLevel.Verbose;
        case "3", "vvv", "everything", "Everything", "EVERYTHING":
          return types.LogLevel.Everything;
        case: 
          return types.LogLevel.Normal;

      }
    }
    case: 
      return types.LogLevel.Normal;
  }
}

into_bool :: proc (value: any) -> bool {
  switch v in value {
    case bool:                          return v;
    case string: {
      switch v {
        case "", "0", "-", "nil", "null", "n", "N", "no", "NO", "false", "False", "FALSE", "none", "None", "NONE":
          return false;
        case "1", "yes", "Yes", "YES", "y", "Y", "true", "True", "TRUE":
          return true;
        case:
          return false;
      }
    }
    case int:                           return v >= 0;
    case types.Node:                    return v.tag != "N/A";
    case types.Error:                   return v == types.ContextError.None || v == types.RendererError.None;
    case types.Option(int):             return is_some(v) && unwrap(v) >= 0;
    case types.Option(bool):            return is_some(v) && unwrap(v);
    case rawptr:                        return v != nil;
    case:                               return false;
  }
}

// TODO: Add Context, Node, and other types.
into_str :: proc {
  into_str_bool,
  into_str_option,
  into_str_node,
  into_str_enum,
  into_str_option_ref,
  into_str_ctx,
  into_str_any,
};

into_str_any :: proc (value: any) -> string {
  switch v in value {
    case string:  return v;
    case types.Option(types.Node):  return into_str_option(types.Node, v);
    case types.Option(^types.Node): return into_str_option_ref(types.Node, v);
    case types.LogLevel:          return into_str_enum(v);
    case ^types.Node:               return into_str_node(v);
    case ^types.Context:            return into_str_ctx(v);
    case:                           return "Unimplemented";
  }
}

into_str_bool :: proc (value: bool) -> string {
  return value ? "true" : "false";
}

into_str_option :: proc ($T: typeid, opt: types.Option(T), indent: string = "\t") -> string {
  #partial switch &value in opt {
    case T: {
      switch &value {
        case nil:             return "None";
        case: 
          if T == types.Node {
            return into_str_node(&value, indent);
          }    

          return "None";
      }
    }
    case rawptr:              return "None";
    case nil:                 return "None";
  }

  return "None";
}

into_str_option_ref :: proc ($T: typeid, opt: types.Option(^T), indent: string = "\t") -> string {
  #partial switch value in opt {
    case ^T: {
      switch value {
        case nil:             return "None";
        case: 
          if T == types.Node {
            return into_str_node(value, indent);
          }

          return "None";
      }
    }
    case rawptr:              return "None";
    case nil:                 return "None";
  }

  return "None";
}

into_str_node :: proc (node: ^types.Node, indent: string = "\t") -> string {
  if node == nil {
    return "nil";
  }
  
  string_builder: strings.Builder = {};
  parent := node.parent != nil ? node.parent.tag : "nil";
  return fmt.sbprintf(&string_builder, "  [{1}] -> {{\n{0}  Parent: {2},\n{0}  id: {3}\n{0}}}", 
    indent, node.tag, parent, node.id);
}

into_str_enum :: proc (debug: types.LogLevel, indent: string = "\t") -> string {
  str, _ := fmt.enum_value_to_string(debug); 
  return str;
}

// Try to prettify an object (preferably tree-like) in a JSON-like structure to pass onto 'printf()'.
//
// @param obj:    Object to deserialize
// @param indent: The amount of horizontal padding to indent any inner-elements.
into_str_ctx :: proc (ctx: ^types.Context, indent: string = "\t    ") -> string {
  string_builder: strings.Builder = {};

  return fmt.sbprintf(&string_builder, "{0}Context: {{\n{0}  Debug Level: {1},\n{0}  Root: {{\n{0}{2}\n{0}}},\n{0}  Window: {3}," +
      "\n{0}  Last Node: {{\n{0}{4}\n{0}}},\n{0}  Cursor: [{5},{6}],\n{0}}}", indent, into_str(ctx.config["log_level"]),
      into_str(ctx.root, "\t\t  "), ctx.window, into_str(ctx.last_node, "\t\t  "), ctx.cursor[0], ctx.cursor[1]);
}
