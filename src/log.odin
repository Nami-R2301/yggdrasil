package yggdrasil;

import "core:fmt";
import "core:strings";

import types "types";
import utils "utils";

print_nodes :: proc(root: ^types.Node, indent: string = "  ", is_root_node: bool = true) {
  if root == nil {
    return;
  }

  node := root^;
  inner_indent := indent;
  left_padding := strings.concatenate({indent, "       "});
  outer_indent := strings.concatenate({left_padding, "    "});


  // If we are root
  if node.parent == nil || is_root_node {
    inner_indent = strings.concatenate({left_padding, "      "});

    fmt.printf("[INFO]:{}| Printing node...\n{}--- ", indent, left_padding);
    fmt.printf("[{1}] -> {{ \n{0}Parent: '{2}' [{3}] (%p), \n{0}id: {5}, \n{0}style: {6}, \n{0}properties: {7}, " +
      "\n{0}children [{8}]: {{", inner_indent, node.tag, node.parent != nil ? node.parent.tag : "nil",
      node.parent != nil ? node.parent.id : 0, node.parent, node.id, node.style, node.properties, len(node.children));
  } else {  
      fmt.printf("\n{0}[{}] -> {{ \n{0}  Parent: '{}' [%d] (%p), \n{0}  id: {}, \n{0}  style: {}, " +
        "\n{0}  properties: {}, \n{0}  children [{}]: {{", indent, node.tag, node.parent.tag, node.parent.id,
        node.parent, node.id, node.style, node.properties, len(node.children)); 
  }

  if !is_root_node {
    inner_indent = strings.concatenate({inner_indent, "    "});
  } else {
    inner_indent = strings.concatenate({inner_indent, "  "});
  }

  if len(node.children) > 0 {
    fmt.printf("\n{}------------", inner_indent);
  }

  for node, &value in node.children {
    if value != nil {
      print_nodes(value, inner_indent, false);
    }
  }

  // CLose children nodes : children [2] : {...}.
  if len(node.children) > 0 {
    if is_root_node {
      fmt.printf("\n{0}}}\n{0}------------\n{1}  }}", inner_indent, outer_indent);
    } else {
      fmt.printf("\n{0}}}\n{0}------------\n{1}  }}", inner_indent, indent);
    }
  } else {
    fmt.print("}");
  }

  // Close parent node: [<node_name>] -> {...}.
  if node.parent == nil || is_root_node {
    fmt.printfln("\n{0}    }}", left_padding);
    fmt.printfln("[INFO]:{}--- Done", indent);
  }
}
