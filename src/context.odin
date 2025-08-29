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

_create_context :: proc (window_handle: glfw.WindowHandle = nil, renderer_handle: ^types.Renderer = nil, config: map[string]types.Option(string)) -> (types.Error, types.Option(types.Context)) {

  sanitize_error, sanitized_config := verify_config(config);
  parse_error, parsed_config := parse_config(sanitized_config);
 
  level: types.LogLevel = utils.into_debug(parsed_config["log_level"]);

  if level != types.LogLevel.None {
    fmt.println("[INFO]:\t| Creating context...");
  }

  if level >= types.LogLevel.Verbose {
    fmt.printfln("[INFO]:\t  --- Config: {}", parsed_config);
  }

  new_window := window_handle;
  new_renderer := renderer_handle;

  error := sanitize_error != types.ContextError.None ? sanitize_error : parse_error;
  if error != types.ContextError.None {
    fmt.eprintfln("[ERR]:\t  --- types.ContextError creating context: {}", error);
    return error, utils.none(types.Context);
  } 

  if window_handle == nil && !utils.into_bool(parsed_config["headless"]) {

    if level >= types.LogLevel.Verbose {
      fmt.println("[WARN]:\t  --- No window handle found, creating window...");
    }

    if !bool(glfw.Init()) {
      fmt.println("[ERR]:\t  --- FATAL: Cannot initialize GLFW");
      return types.ContextError.GlfwError, utils.none(types.Context);
    }
    new_window = glfw.CreateWindow(800, 600, "Default Window", nil, nil);

    target: string = utils.into_str(parsed_config["target"]);

    glfw.WindowHint_bool(glfw.OPENGL_DEBUG_CONTEXT, target == "debug");
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE);
    glfw.WindowHint(glfw.VERSION_MAJOR, 3);
    glfw.WindowHint(glfw.VERSION_MINOR, 3);
    glfw.SwapInterval(1);
    glfw.MakeContextCurrent(window_handle);

    renderer_error, renderer_opt := renderer._create_renderer(type = types.RendererType.OpenGL, bg_color = 0x181818);
    if renderer_error != types.RendererError.None {
      return types.RendererError.InitError, utils.none(types.Context);
    }
    new_renderer = new_clone(utils.unwrap(renderer_opt));
  }

  if level != types.LogLevel.None {
    fmt.println("[INFO]:\t  --- Created context");
  }
  
  return types.ContextError.None, utils.some(types.Context {
    window = new_window,
    root = nil,
    last_node = nil,
    cursor = {0, 0},
    renderer = new_renderer, 
    config = parsed_config,
  });
}

_reset_context :: proc (ctx: ^types.Context) -> types.ContextError {
  assert(ctx != nil, "[ERR]:\t| types.ContextError resetting context: Context is nil!");

  level: types.LogLevel = utils.into_debug(ctx.config["log_level"]);
  if level >= types.LogLevel.Normal {
    fmt.printfln("[INFO]:\t| Resetting context (%p) ... ->\n{}", ctx, utils.into_str(ctx));
  }

  ctx.config["log_level"] = "0";
  ctx.root = nil;
  ctx.window = nil;
  ctx.cursor = {0, 0};
  ctx.last_node = nil;

  if level >= types.LogLevel.Normal {
    fmt.printfln("[INFO]:\t  --- Reset context (%p) ->\n{}", ctx, utils.into_str(ctx, "\t\t"));
  }

  return types.ContextError.None;
}

_destroy_context :: proc (ctx: ^types.Context) -> types.ContextError {
  assert(ctx != nil, "[ERR]:\t| types.ContextError resetting context: Context is nil!");
  
  level: types.LogLevel = utils.into_debug(ctx.config["log_level"]);
  if level >= types.LogLevel.Normal {
    fmt.printfln("[INFO]:\t| Destroying context (%p) ... ->\n{}", ctx, utils.into_str(ctx));
  }


  if ctx.root != nil {
    if level >= types.LogLevel.Verbose {
      fmt.println("[INFO]:\t  --- Destroying nodes...");
    }

    _ = _detach_node(ctx, ctx.root.id); 
  }

  if !utils.into_bool(ctx.config["headless"]) {
    _ = renderer._destroy_renderer(ctx.renderer);
  }

  if level >= types.LogLevel.Verbose {
    fmt.printfln("[INFO]:\t  --- Destroying window (%p)...", ctx.window);
  }

  if ctx.window != nil {
    glfw.DestroyWindow(ctx.window);
  }

  if level >= types.LogLevel.Normal {
    fmt.printfln("[INFO]:\t  --- Destroyed context (%p) ->\n{}", ctx, utils.into_str(ctx, "\t\t"));
  } 

  return types.ContextError.None;
}
