package ui;

import "core:fmt";
import "../core";

create_node :: proc (ctx: ^core.Context, tag: string,  at: core.Option(u16) = nil, style: map[string]any = {}, properties: map[string]any = {}) -> core.Node {
    if ctx.debug_level >= core.DebugLevel.None {
      fmt.printfln("[INFO]:\t| Creating node [%s]...", tag);
    }

    placement: u16 = 0;
    if ctx.last_node != nil {
      placement = core.unwrap_or(at, (ctx.last_node^).id);
    } 
    
    return core.Node {
      parent = ctx.last_node,
      id = placement + 1,
      tag = tag,
      style = style,
      properties = properties
    };
}
