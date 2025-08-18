package core;

import "vendor:glfw";
import "core:fmt";
import "core:strconv";

Context :: struct {
  window:       glfw.WindowHandle,
  root:         Node,
  nodes:        map[string]Node,
  last_node:    ^Node,
  cursor:       [2]u16,
  framebuffers: []Framebuffer,
  textures:     []Texture,
  vbos:         []Vbo,
  debug_level:  DebugLevel
}


create_context :: proc (window: glfw.WindowHandle = nil, config: map[string]string = {}, root: Node = {
  parent = nil,
  id = 0,
  tag = "root",
  style = {},
  properties = {}
}) -> Context {
  new_window := window;

  fmt.println("[INFO]:\tCreating context...");

  if window == nil {
    fmt.println("[INFO]: Creating window...");
    assert(bool(glfw.Init()), "FATAL: Cannot initialize GLFW");
    new_window = glfw.CreateWindow(800, 600, "Default Window", nil, nil);
    glfw.SwapInterval(1);
    glfw.MakeContextCurrent(new_window);
  }

  new_root := root;
  nodes: map[string]Node = {} 
  // Default config
  debug_level := DebugLevel.Normal;

  if len(config) > 0 {
    sanitized_config, verify_error := verify_config(config);
    debug_level, style, properties, nodes, parse_error := parse_config(sanitized_config);

    new_root.style = style;
    new_root.properties = properties;
  }

  return Context {
    window = new_window,
    root = root,
    nodes = nodes,
    last_node = nil,
    cursor = {0, 0},
    framebuffers = {},
    textures = {},
    vbos = {},
    debug_level = debug_level,
  };
}

destroy_context :: proc (ctx: Context) {
  fmt.println("[INFO]:\tDestroying context...");
  if ctx.window == nil {
    return;
  }

  fmt.println("[INFO]:\t| Destroying nodes...");
  delete (ctx.nodes);

  fmt.printfln("[INFO]:\t| Destroying window (%p)...", ctx.window);

  glfw.DestroyWindow(ctx.window);
}
