package yggdrasil;

import "vendor:glfw";
import "core:fmt";
import "core:strings";

import "renderer";
import "types";
import "utils";

////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////// HIGH LEVEL API /////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////

init :: proc (window: ^glfw.WindowHandle = nil, width: types.Option(types.Id) = nil, height: types.Option(types.Id) = nil, x: types.Option(types.Id) = nil,
  y: types.Option(types.Id) = nil) -> (types.ContextError, types.Option(types.Context)) {

  return types.ContextError.None, utils.none(types.Context); 
}

terminate :: proc (ctx: ^types.Context) -> types.ContextError {
  return types.ContextError.None;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////// LOW LEVEL API //////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////

_create_context :: proc (window_handle: glfw.WindowHandle = nil, renderer_handle: ^types.Renderer = nil, config: map[string]types.Option(string) = {}, indent: string = "  ") -> (types.Error, types.Option(types.Context)) {
  sanitize_error, sanitized_config := verify_config(config);
  parse_error, parsed_config := parse_config(sanitized_config);
 
  level: types.LogLevel = utils.into_debug(parsed_config["log_level"]);

  if level != types.LogLevel.None {
    fmt.printfln("[INFO]:{}| Creating context...", indent);
  }

  if level >= types.LogLevel.Verbose {
    fmt.printfln("[INFO]:{}  --- Config initialized: {}", indent, parsed_config);
  }

  new_window := window_handle;
  new_renderer := renderer_handle;

  error := sanitize_error != types.ContextError.None ? sanitize_error : parse_error;
  if error != types.ContextError.None {
    fmt.eprintfln("[ERR]:{}--- Error creating context: {}", indent, error);
    return error, utils.none(types.Context);
  } 

  if window_handle == nil && !utils.into_bool(parsed_config["headless"]) {

    if level >= types.LogLevel.Verbose {
      fmt.printfln("[WARN]:{}  --- No window handle found, creating window...", indent);
    }

    if !bool(glfw.Init()) {
      fmt.printfln("[ERR]:{}--- FATAL: Cannot initialize GLFW", indent);
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

  ctx := types.Context {
    window = new_window,
    root = nil,
    last_node = nil,
    cursor = {0, 0},
    renderer = new_renderer, 
    config = parsed_config,
  };

  if level != types.LogLevel.None {
    str := utils.into_str(&ctx, "           ");
    fmt.printfln("[INFO]:{0}--- Done (\n{2} {1}\n         )", indent, str, "          ");
    delete_string(str);
  }
  
  return types.ContextError.None, utils.some(ctx);
}

_reset_context :: proc (ctx: ^types.Context, indent: string = "  ") -> types.ContextError {
  assert(ctx != nil, "[ERR]:\t| types.ContextError resetting context: Context is nil!");

  level: types.LogLevel = utils.into_debug(ctx.config["log_level"]);
  if level >= types.LogLevel.Normal {
    str := utils.into_str(ctx);
    fmt.printfln("[INFO]:{}| Resetting context (%p) ... :\n{}", indent, ctx, str);
    delete_string(str);
  }

  ctx.config["log_level"] = "0";
  ctx.root = nil;
  ctx.window = nil;
  ctx.cursor = {0, 0};
  ctx.last_node = nil;

  if level >= types.LogLevel.Normal {
    str := utils.into_str(ctx, "    ");
    fmt.printfln("[INFO]:{}--- Done (%p) :\n{}", indent, ctx, str);
    delete_string(str);
  }

  return types.ContextError.None;
}

_destroy_context :: proc (ctx: ^types.Context, indent: string = "  ") -> types.ContextError {
  assert(ctx != nil, "[ERR]:\t| types.ContextError resetting context: Context is nil!");
  
  level: types.LogLevel = utils.into_debug(ctx.config["log_level"]);
  if level >= types.LogLevel.Normal {
    fmt.printfln("[INFO]:{}| Destroying context (%p) ...", indent, ctx);
  }

  if ctx.root != nil {
    new_indent , _ := strings.concatenate({indent, "  "});

    for child_id, _ in ctx.root.children {
      _ = _destroy_node(ctx, child_id, new_indent);
    }

    delete_string(new_indent);
  }

  delete_map(ctx.root.children);
  free(ctx.root);

  if !utils.into_bool(ctx.config["headless"]) {
    _ = renderer._destroy_renderer(ctx.renderer);
  }

  if level >= types.LogLevel.Verbose {
    fmt.printf("[INFO]:{}  | Destroying window (%p)...", indent, ctx.window);
  }

  if ctx.window != nil {
    glfw.DestroyWindow(ctx.window);
  }

  if level >= types.LogLevel.Normal {
    fmt.println(" Done");
    fmt.printfln("[INFO]:{}--- Done", indent);
  }

  delete_map(ctx.config);

  return types.ContextError.None;
}
