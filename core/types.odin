package core;


FileError :: enum {
  None,
  FileNotFound,
  ReadError,
  PermissionError,
  FileTooBig,
  FileLocked,
  InvalidConfig
}

Framebuffer :: struct {
}

Texture :: struct {
}

Vbo :: struct {
}


Node :: struct {
  parent: ^Node,
  id: u16,
  tag: string,
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
  switch _ in opt {
    case T:     return true;
    case nil:  return false;
  }
}

unwrap :: proc (opt: Option($T)) -> T {
  switch value in opt {
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
