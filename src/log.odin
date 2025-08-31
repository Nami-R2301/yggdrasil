package yggdrasil;

import "core:fmt";
import "core:strings";

import types "types";
import utils "utils";

print_nodes :: proc(root: ^types.Node, indent: string = "  ", inner_indent: string = "         ") {
  if root == nil {
    return;
  }

  node := root^;
  left_padding := "        ";

  // If we are root
  if node.parent == nil {
    fmt.printf("[INFO]:{0}| Printing node...\n{1}--- ", indent, inner_indent);
    fmt.printf("[{1}] -> {{ \n{0}      Parent: nil, \n{0}      id: {}, \n{0}      style: {}, \n{0}      properties: {}, " +
      "\n{0}      children [{}]: {{", inner_indent, node.tag, node.id, node.style, node.properties, len(node.children));
  } else {
      fmt.printf("\n{0}      [{2}] -> {{ \n{0}{1}Parent: '{}' [%d] (%p), \n{0}{1}id: {}, \n{0}{1}style: {}, " +
        "\n{0}{1}properties: {}, \n{0}{1}children [{}]: {{", inner_indent, left_padding, node.tag, node.parent.tag, node.parent.id,
        node.parent, node.id, node.style, node.properties, len(node.children)); 
  }

  if len(node.children) > 0 {
    fmt.printf("\n{0}{}------------", inner_indent, left_padding);
  }

  for node, &value in node.children {
    new_indent: string = strings.concatenate({inner_indent, "  "});
    if value != nil {
      print_nodes(value, indent, new_indent);
    }
  }

  if len(node.children) > 0 {
    fmt.printf("\n{0}{1}}}\n{0}{1}------------\n{0}      }}", inner_indent, left_padding);  // children block
    fmt.printfln("\n{0}    }}", inner_indent);  // main node block
  } else {
    fmt.print("}");
  }

  if node.parent == nil {
    fmt.printfln("[INFO]:{}--- Done", indent);
  }
}
