package types;

import "vendor:glfw";

// Aggregate all errors into this type when a procedure might return multiple types of errors.
Error :: union {
  ContextError,
  RendererError
}

// Errors regarding the overall app context.
ContextError :: enum u8 {
  None = 0,
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

// App logging to stdout. Defaults to Normal (0).
LogLevel :: enum u8 {
  None       = 0,
  Normal     = 1,
  Verbose    = 2,
  Everything = 3,
}

Context :: struct {
  window:       glfw.WindowHandle,
  root:         ^Node,
  last_node:    ^Node,
  cursor:       [2]u16,
  renderer:     ^Renderer,
  config:       map[string]string
}
