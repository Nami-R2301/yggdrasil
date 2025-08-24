package core;

import "vendor:glfw";
import "core:fmt";

create_context :: proc (window: glfw.WindowHandle = nil, config: map[string]string = {}, root: Node = {
  parent = nil,
  id = 0,
  tag = "root",
  style = {},
  properties = {}
}) -> Context {
  new_window := window;

  fmt.println("[INFO]:\t| Creating context...");

  if window == nil {
    fmt.println("[INFO]:\t  --- Creating window...");
    assert(bool(glfw.Init()), "FATAL: Cannot initialize GLFW");
    new_window = glfw.CreateWindow(800, 600, "Default Window", nil, nil);
    glfw.SwapInterval(1);
    glfw.MakeContextCurrent(new_window);
  }

  // Default config
  debug_level := DebugLevel.Verbose;
  
  new_root := root;
  if len(config) > 0 {
    sanitized_config, verify_error := verify_config(config);
    debug_level, style, properties, parse_error := parse_config(sanitized_config);

    new_root.style = style;
    new_root.properties = properties;
  }

  return Context {
    window = new_window,
    root = new_clone(root),
    last_node = none(Node),
    cursor = {0, 0},
    framebuffers = {},
    textures = {},
    vbos = {},
    debug_level = debug_level,
  };
}

destroy_context :: proc (ctx: Context) {
  fmt.println("[INFO]:\t| Destroying context...");
  if ctx.window == nil {
    return;
  }

  fmt.println("[INFO]:\t  --- Destroying nodes...");
  delete (ctx.root.style);
  delete (ctx.root.properties);
  delete (ctx.root.children);

  fmt.printfln("[INFO]:\t  --- Destroying window (%p)...", ctx.window);

  glfw.DestroyWindow(ctx.window);
}


create_node :: proc (ctx: ^Context, tag: string,  at: ^Node = nil, style: map[string]any = {}, properties: map[string]any = {}, children: map[string]Option(Node) = {}) -> Node {
    if ctx.debug_level >= DebugLevel.Normal {
      fmt.printfln("[INFO]:\t| Creating node [%s]...", tag);
    }

    placement: ^Node = at != nil ? at : ctx.root;
    if is_some(ctx.last_node) {
      placement = new_clone(unwrap_or(ctx.last_node, Node {id = 0}));
    } 
    
    if ctx.debug_level >= DebugLevel.Verbose {
      fmt.printfln("[INFO]:\t  --- Parent = %s, id = %d, tag = %s, style = {}, properties = {}, children = {}", ctx.last_node, placement.id + 1, tag, style, properties, children);
    }

    return Node {
      parent = placement,
      id = placement.id + 1,
      tag = tag,
      children = children,
      style = style,
      properties = properties
    };
}

add_node :: proc (ctx: ^Context, node: Node) -> Error {
  if ctx.debug_level >= DebugLevel.Verbose {
    fmt.println("[INFO]:\t| Adding node to context tree...");
  }

  if ctx == nil {
    return Error.UinitializedContext;
  }

  if node.parent != nil && node.parent != ctx.root {
    node := find_node(ctx, node.tag);

    if is_some(node) {
      parent := unwrap(node).parent;
    
      if parent != nil {
        parent.children[unwrap(node).tag] = node;
      }
    }
    return Error.None;
  }

  ctx.root.children[node.tag] = some(node);
  fmt.printfln("[INFO]:\t  --- Added {} to {}", node.tag, ctx.root.tag);
  return Error.None
}

remove_node :: proc (ctx: ^Context, tag: string) -> (Option(Node), Error) {
  if ctx == nil {
    return none(Node), Error.UinitializedContext;
  }
  
  node := find_node(ctx, tag);
  if !is_some(node) {
    return node, Error.None;
  }

  parent := unwrap(node).parent;

  if parent != nil {
    parent.children[unwrap(node).tag] = {};
  }

  return node, Error.None;
}

find_node :: proc (ctx: ^Context, tag: string) -> Option(Node) {
  return none(Node);
}
