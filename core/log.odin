package core;

import "core:fmt";
import "core:strings";

DebugLevel :: enum u8 {
  None       = 0,
  Normal     = 1,
  Verbose    = 2,
  Everything = 3
}

print_nodes :: proc(ctx: Context, from: Option(u16), to: Option(u16)) {
  indent := "";

  for node, &value in ctx.nodes {
    if value.parent != nil {
      fmt.printfln("%s|", indent);
    }
    
    fmt.printfln("%s", node);

    fmt.printfln("- %s -> {", node);
    fmt.printfln("%s  id: %d", indent, value.id);

    // Styles
    fmt.printfln("%s  style: {", indent);

    for property, &value in value.style {
      fmt.printfln("%s    %s -> %s", property, value);
    }

    fmt.printfln("%s  }", indent);
    strings.concatenate({indent, "  "});
  }
}
