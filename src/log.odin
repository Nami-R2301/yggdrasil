package yggdrasil;

import "core:fmt";
import "core:strings";

import types "types";
import utils "utils";

print_nodes :: proc(root: ^types.Node, indent: string = "\t") {
  if root == nil {
    return;
  }

  node := root^;

  // If we are root
  if node.parent == nil {
    fmt.printf("[INFO]: [{1}] -> {{ \n{0}  Parent = None, \n{0}  id = {2}, \n{0}  style = {3}, \n{0}  properties = {4}, \n{0}  children = {{", 
      indent, node.tag, node.id, node.style, node.properties);
  } else {
      fmt.printf("\n{0}[{1}] -> {{ \n{0}  Parent = '{2}' [%p], \n{0}  id = {4}, \n{0}  style = {5}, \n{0}  properties = {6}, \n{0}  children = {{", 
        indent, node.tag, node.parent.tag, node.parent, node.id, node.style, node.properties); 
  }

  if len(node.children) > 0 {
    fmt.printf("\n{0}    ------------", indent);
  }

  for node, &value in node.children {
    new_indent: string = strings.concatenate({indent, "    "});
    if utils.is_some(value) {
      unwrapped := utils.unwrap(value);
      print_nodes(&unwrapped, new_indent);
    }
  }

  if len(node.children) > 0 {
    fmt.printf("\n{0}    }}\n{0}    ------------\n{0}  }}", indent);  // children block
    fmt.printfln("\n{0}}}", indent);  // main node block
  } else {
    fmt.print("}");
  }
}
