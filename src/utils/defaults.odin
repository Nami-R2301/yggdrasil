package utils;

import "vendor:glfw";

import "../types";

default :: proc {
  default_bool,
  default_str,
  default_opt,
  default_node,
  default_ctx,
  default_log_level,
  default_config,
}

@(export, link_prefix="ygg_utils_", require_results)
default_bool :: proc "c" (value: bool) -> bool {
  return false;
}

@(export, link_prefix="ygg_utils_", require_results)
default_str :: proc (str: string) -> string {
  return "-";
}

@(export, link_prefix="ygg_utils_", require_results)
default_opt :: proc "c" (opt: Maybe($T)) -> T {
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

@(export, link_prefix="ygg_utils_", require_results)
default_node :: proc "c" (node: types.Node) -> types.Node {
  return types.Node {
    parent = nil,
    tag = "N/A",
    id = 0,
    style = {},
    children = {}
  };
}

@(export, link_prefix="ygg_utils_", require_results)
default_ctx :: proc "c" (ctx: types.Context) -> types.Context {
  return types.Context {
    window = nil,
    root = nil,
    last_node = nil,
    cursor = {0, 0},
    renderer = nil,
    config = {}
  };
}

@(export, link_prefix="ygg_utils_", require_results)
default_log_level :: proc "c" (log: types.LogLevel) -> types.LogLevel {
  return types.LogLevel.Normal;
}

@(export, link_prefix="ygg_utils_", require_results)
default_config :: proc "c" () -> map[string]string {
  default: map[string]string = {};

  default["log_level"]    = "v";
  default["target"]       = "x86_64";
  default["headless"]     = "false";
  default["test_mode"]    = "false";
  default["optimization"] = "debug";
  default["cache"]        = "true";

  return default;
}

@(export, link_prefix="ygg_utils_", require_results)
default_window :: proc "c" (window: types.Window = {}) -> types.Window {
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
  new_window.width = 800;
  new_window.height = 600;
  new_window.offset = { 0, 0 };
  new_window.refresh_rate_opt = 0;

  return new_window;
}
