package core;

import "vendor:glfw";


Error :: enum {
  None,
  FileNotFound,
  ReadError,
  PermissionError,
  FileTooBig,
  FileLocked,
  InvalidConfig,
  UinitializedContext
}

Framebuffer :: struct {
}

Texture :: struct {
}

Vbo :: struct {
}


Context :: struct {
  window:       glfw.WindowHandle,
  root:         ^Node,
  last_node:    Option(Node),
  cursor:       [2]u16,
  framebuffers: []Framebuffer,
  textures:     []Texture,
  vbos:         []Vbo,
  debug_level:  DebugLevel
}

Node :: struct {
  parent: ^Node,
  id: u16,
  tag: string,
  children: map[string]Option(Node),
  style: map[string]any,
  properties: map[string]any
}

// Optional type in odin
Option :: union($T: typeid) {
  T,
  rawptr
}

some :: proc (value: $T) -> Option(T) {
  return value;
}

none :: proc ($T: typeid) -> Option(T) {
  return nil;
}

is_some :: proc(opt: Option($T)) -> bool {
  #partial switch _ in opt {
    case T:     return true;
    case nil:  return false;
  }
  return false;
}

unwrap :: proc (opt: Option($T)) -> T {
  #partial switch value in opt {
    case T:       return value;
    case rawptr:  panic("Unwrapping a None Value");
    case nil:     panic("Unwrapping a None value");
  }

  return T{};  // Unreachable
}

unwrap_or :: proc (opt: Option($T), default: T) -> T {
  switch value in opt {
    case T:        return value;
    case rawptr:   return default;
    case nil:      return default;
  }

  return default;
}
