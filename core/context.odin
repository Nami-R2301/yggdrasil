package core;

import "vendor:glfw";
import "core:fmt";

create_context :: proc (window: glfw.WindowHandle = nil, config: map[string]string = {}, debug_level: DebugLevel = DebugLevel.Verbose, root: Node = {
  parent = nil,
  id = 0,
  tag = "root",
  style = {},
  properties = {}
}) -> Context {
  new_window := window;

  if debug_level >= DebugLevel.Normal {
    fmt.println("[INFO]:\t| Creating context...");
  }

  if window == nil {

    if debug_level >= DebugLevel.Verbose {
      fmt.println("[WARN]:\t  --- No window handle found, creating window...");
    }

    assert(bool(glfw.Init()), "FATAL: Cannot initialize GLFW");
    new_window = glfw.CreateWindow(800, 600, "Default Window", nil, nil);
    glfw.SwapInterval(1);
    glfw.MakeContextCurrent(new_window);
  }
  
  new_root := root;
  if len(config) > 0 {
    sanitized_config, verify_error := verify_config(config);
    debug_level, style, properties, parse_error := parse_config(sanitized_config);

    new_root.style = style;
    new_root.properties = properties;
  }

  if debug_level >= DebugLevel.Normal {
    fmt.printfln("[INFO]:\t  --- Created context with root node '{}' [{}]", root.tag, root.id);
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
  if ctx.debug_level >= DebugLevel.Normal {
    fmt.printfln("[INFO]:\t| Destroying context ... ->\n{}", to_str(ctx));
  }

  if ctx.window == nil {
    return;
  }

  if ctx.debug_level >= DebugLevel.Verbose {
    fmt.println("[INFO]:\t  --- Destroying nodes...");
  }

  delete (ctx.root.style);
  delete (ctx.root.properties);
  delete (ctx.root.children);

  if ctx.debug_level >= DebugLevel.Verbose {
    fmt.printfln("[INFO]:\t  --- Destroying window (%p)...", ctx.window);
  }

  if ctx.debug_level >= DebugLevel.Normal {
    fmt.printfln("[INFO]:\t  --- Destroyed context ->\n{}", to_str(ctx, "\t\t"));
  }

  glfw.DestroyWindow(ctx.window);
}
