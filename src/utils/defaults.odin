package utils;

import "vendor:glfw";

import "../types";
import "../utils";

default :: proc {
  default_bool,
  default_str,
  default_opt,
  default_node,
  default_ctx,
  default_log_level,
  default_config,
}

default_bool :: proc (value: bool) -> bool {
  return false;
}

default_str :: proc (str: string) -> string {
  return "-";
}

default_opt :: proc (opt: types.Option($T)) -> T {
  switch v in opt {
    case types.Node: 
        return default_node(v);
    case types.ContextError: 
      return types.ContextError.None;
    case types.RendererError:
      return types.RendererError.None;
    case types.LogLevel:
      return default_log_level(v);
    case types.Context:
      return default_ctx(v);
    case:
      return v;
  }
}

default_node :: proc (node: types.Node) -> types.Node {
  return types.Node {
    parent = nil,
    tag = "N/A",
    id = 0,
    style = {},
    properties = {},
    children = {}
  };
}

default_ctx :: proc (ctx: types.Context) -> types.Context {
  return types.Context {
    window = nil,
    root = nil,
    last_node = nil,
    cursor = {0, 0},
    renderer = nil,
    config = {}
  };
}

default_log_level :: proc (log: types.LogLevel) -> types.LogLevel {
  return types.LogLevel.Normal;
}

default_config :: proc (config: map[string]string = {}) -> map[string]string {
  default: map[string]string = {};

  default["log_level"]    = "v";
  default["target"]       = "x86_64";
  default["headless"]     = "false";
  default["test_mode"]    = "false";
  default["renderer"]     = "OpenGL";
  default["optimization"] = "debug";
  default["cache"]        = "true";

  return default;
}

default_window :: proc (window: types.Window = {}) -> types.Window {
  new_window: types.Window = {};
  glfw_handle := glfw.CreateWindow(800, 600, "Default Window", nil, nil);

  glfw.WindowHint_bool(glfw.OPENGL_DEBUG_CONTEXT, true);
  glfw.WindowHint(glfw.CLIENT_API, glfw.OPENGL_API);
  glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE);
  glfw.WindowHint(glfw.VERSION_MAJOR, 3);
  glfw.WindowHint(glfw.VERSION_MINOR, 3);

  glfw.WindowHint(glfw.REFRESH_RATE, -1);

  glfw.SwapInterval(1);
  glfw.MakeContextCurrent(glfw_handle);

  new_window.glfw_handle = glfw_handle;
  new_window.title = "Yggdrasil";
  new_window.dimensions = { 800, 600 };
  new_window.offset = { 0, 0 };
  new_window.refresh_rate = utils.none(u16);

  return new_window;
}
