package core;

import "vendor:glfw";
import "core:fmt";

create_context :: proc (window: glfw.WindowHandle = nil, config: map[string]Option(string)) -> Context {
  new_window := window;
  sanitized_config, verify_error := verify_config(config);
  debug_level, parse_error := parse_config(sanitized_config);

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
  
  if debug_level >= DebugLevel.Normal {
    fmt.println("[INFO]:\t  --- Created context");
  }

  return Context {
    window = new_window,
    root = nil,
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
