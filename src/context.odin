package yggdrasil;

import "vendor:glfw";
import "core:fmt";

import "renderer";
import "types";
import "utils";

////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////// HIGH LEVEL API /////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////

init :: proc (window: ^glfw.WindowHandle = nil, width: types.Option(u16) = nil, height: types.Option(u16) = nil, x: types.Option(u16) = nil,
  y: types.Option(u16) = nil) -> (types.ContextError, types.Option(types.Context)) {

  return types.ContextError.None, utils.none(types.Context); 
}

terminate :: proc () -> types.ContextError {
  return types.ContextError.None;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////// LOW LEVEL API //////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////

_create_context :: proc (window: glfw.WindowHandle = nil, config: map[string]types.Option(string)) -> (types.Error, types.Option(types.Context)) {
  new_window := window; 

  sanitize_error, sanitized_config := verify_config(config);
  parse_error, debug_level, target := parse_config(sanitized_config);
  
  error := sanitize_error != types.ContextError.None ? sanitize_error : parse_error
  if error != types.ContextError.None {
    fmt.eprintfln("[ERR]:\t  --- types.ContextError creating context: {}", error);
    return error, utils.none(types.Context);
  }

  if debug_level >= types.DebugLevel.Normal {
    fmt.println("[INFO]:\t| Creating context...");
  }

  if window == nil && !utils.is_some(sanitized_config["test_mode"]) {

    if debug_level >= types.DebugLevel.Verbose {
      fmt.println("[WARN]:\t  --- No window handle found, creating window...");
    }

    if !bool(glfw.Init()) {
      fmt.println("[ERR]:\t  --- FATAL: Cannot initialize GLFW");
      return types.ContextError.GlfwError, utils.none(types.Context);
    }
    new_window = glfw.CreateWindow(800, 600, "Default Window", nil, nil);
    glfw.WindowHint_bool(glfw.OPENGL_DEBUG_CONTEXT, target == "debug");
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE);
    glfw.WindowHint(glfw.VERSION_MAJOR, 3);
    glfw.WindowHint(glfw.VERSION_MINOR, 3);
    glfw.SwapInterval(1);
    glfw.MakeContextCurrent(new_window);
  }

  renderer_error, renderer_opt := renderer._create_renderer(type = types.RendererType.OpenGL, bg_color = 0x181818);
  if renderer_error != types.RendererError.None {
    return types.RendererError.InitError, utils.none(types.Context);
  }

  if debug_level >= types.DebugLevel.Normal {
    fmt.println("[INFO]:\t  --- Created context");
  }

  return types.ContextError.None, utils.some(types.Context {
    window = new_window,
    root = nil,
    last_node = nil,
    cursor = {0, 0},
    renderer = new_clone(utils.unwrap(renderer_opt)), 
    debug_level = debug_level,
  });
}

_reset_context :: proc (ctx: ^types.Context) -> types.ContextError {
  assert(ctx != nil, "[ERR]:\t| types.ContextError resetting context: Context is nil!");

  if ctx.debug_level >= types.DebugLevel.Normal {
    fmt.printfln("[INFO]:\t| Resetting context (%p) ... ->\n{}", ctx, utils.to_str(ctx));
  }

  ctx.debug_level = types.DebugLevel.None;
  ctx.root = nil;
  ctx.window = nil;
  ctx.cursor = {0, 0};
  ctx.last_node = nil;

  if ctx.debug_level >= types.DebugLevel.Normal {
    fmt.printfln("[INFO]:\t  --- Reset context (%p) ->\n{}", ctx, utils.to_str(ctx, "\t\t"));
  }

  return types.ContextError.None;
}

_destroy_context :: proc (ctx: ^types.Context) -> types.ContextError {
  assert(ctx != nil, "[ERR]:\t| types.ContextError resetting context: Context is nil!");

  if ctx.debug_level >= types.DebugLevel.Normal {
    fmt.printfln("[INFO]:\t| Destroying context (%p) ... ->\n{}", ctx, utils.to_str(ctx));
  }


  if ctx.root != nil {
    if ctx.debug_level >= types.DebugLevel.Verbose {
      fmt.println("[INFO]:\t  --- Destroying nodes...");
    }

    _ = _detach_node(ctx, ctx.root.id); 
  }

  _ = renderer._destroy_renderer(ctx.renderer);

  if ctx.debug_level >= types.DebugLevel.Verbose {
    fmt.printfln("[INFO]:\t  --- Destroying window (%p)...", ctx.window);
  }

  if ctx.window != nil {
    glfw.DestroyWindow(ctx.window);
  }

  if ctx.debug_level >= types.DebugLevel.Normal {
    fmt.printfln("[INFO]:\t  --- Destroyed context (%p) ->\n{}", ctx, utils.to_str(ctx, "\t\t"));
  } 

  return types.ContextError.None;
}
