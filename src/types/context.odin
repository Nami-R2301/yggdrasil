package types;

import "vendor:glfw";

Error :: union {
  ContextError,
  RendererError
}

ContextError :: enum {
  None,
  InvalidContext,
  InvalidWindow,
  GlfwError,
  FileNotFound,
  ReadError,
  PermissionError,
  FileTooBig,
  FileLocked,
  InvalidConfig,
  UinitializedContext,
  DuplicateId,
  NodeNotFound,
  RendererError
}

DebugLevel :: enum u8 {
  None       = 0,
  Normal     = 1,
  Verbose    = 2,
  Everything = 3
}

Context :: struct {
  window:       glfw.WindowHandle,
  root:         ^Node,
  last_node:    ^Node,
  cursor:       [2]u16,
  renderer:     ^Renderer,
  debug_level:  DebugLevel
}
