package core;

import "vendor:glfw";
import "core:fmt";

create_context :: proc (window: glfw.WindowHandle = nil, config: map[string]Option(string)) -> (Error, Option(Context)) {
  new_window := window; 

  sanitize_error, sanitized_config := verify_config(config);
  parse_error, debug_level := parse_config(sanitized_config);
  
  error := sanitize_error != Error.None ? sanitize_error : parse_error
  if error != Error.None {
    fmt.eprintfln("[ERR]:\t  --- Error creating context: {}", error);
    return error, none(Context);
  }

  if debug_level >= DebugLevel.Normal {
    fmt.println("[INFO]:\t| Creating context...");
  }

  if window == nil && !is_some(sanitized_config["test_mode"]) {

    if debug_level >= DebugLevel.Verbose {
      fmt.println("[WARN]:\t  --- No window handle found, creating window...");
    }

    if !bool(glfw.Init()) {
      fmt.println("[ERR]:\t  --- FATAL: Cannot initialize GLFW");
      return Error.GlfwError, none(Context);
    }
    new_window = glfw.CreateWindow(800, 600, "Default Window", nil, nil);
    glfw.SwapInterval(1);
    glfw.MakeContextCurrent(new_window);
  }
  
  if debug_level >= DebugLevel.Normal {
    fmt.println("[INFO]:\t  --- Created context");
  }

  return Error.None, some(Context {
    window = new_window,
    root = nil,
    last_node = nil,
    cursor = {0, 0},
    framebuffers = {},
    textures = {},
    vbos = {},
    debug_level = debug_level,
  });
}

reset_context :: proc (ctx: ^Context) -> Error {
  assert(ctx != nil, "[ERR]:\t| Error resetting context: Context is nil!");

  if ctx.debug_level >= DebugLevel.Normal {
    fmt.printfln("[INFO]:\t| Resetting context (%p) ... ->\n{}", ctx, to_str(ctx));
  }

  ctx.debug_level = DebugLevel.None;
  ctx.root = nil;
  ctx.window = nil;

  ctx.vbos = {};
  ctx.cursor = {0, 0};
  ctx.last_node = nil;
  ctx.textures = {};
  ctx.framebuffers = {};

  if ctx.debug_level >= DebugLevel.Normal {
    fmt.printfln("[INFO]:\t  --- Reset context (%p) ->\n{}", ctx, to_str(ctx, "\t\t"));
  }

  return Error.None;
}

destroy_context :: proc (ctx: ^Context) -> Error {
  assert(ctx != nil, "[ERR]:\t| Error resetting context: Context is nil!");

  if ctx.debug_level >= DebugLevel.Normal {
    fmt.printfln("[INFO]:\t| Destroying context (%p) ... ->\n{}", ctx, to_str(ctx));
  }


  if ctx.root != nil {
    if ctx.debug_level >= DebugLevel.Verbose {
      fmt.println("[INFO]:\t  --- Destroying nodes...");
    }

    _ = detach_node(ctx, ctx.root.id); 
  }

  if ctx.debug_level >= DebugLevel.Verbose {
    fmt.printfln("[INFO]:\t  --- Destroying window (%p)...", ctx.window);
  }

  if ctx.window != nil {
    glfw.DestroyWindow(ctx.window);
  }

  if ctx.debug_level >= DebugLevel.Normal {
    fmt.printfln("[INFO]:\t  --- Destroyed context (%p) ->\n{}", ctx, to_str(ctx, "\t\t"));
  } 

  return Error.None;
}
