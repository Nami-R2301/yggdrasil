package types;

import      "core:os";
import      "base:runtime";

// Aggregate all errors into this type when a procedure might return multiple types of errors.
Error :: union {
  ContextError,
  NodeError,
  WindowError,
  RendererError,
  ConfigError,
  BufferError,
  ProgramError,
  ShaderError,
  TextureError,
  FontError,
  os.Error,
  runtime.Allocator_Error
}


// Rust-like optional type in odin.
Option :: union ($T: typeid) {
  T,
  rawptr
}

// File types supported for loading UI elements from common web formats.
// TODO: Add support for this, low on the priority list for now. 
FileType :: enum u8 {
  unsupported = 0,
  html,
  css,
  toml,
  js
}

// App logging to stdout. Defaults to Normal (0).
LogLevel :: enum u8 {
  None       = 0,
  Normal     = 1,
  Verbose    = 2,
  Everything = 3,
}

ConfigError :: enum u8 {
  None = 0,
  FileNotFound,
  ReadError,
  PermissionError,
  FileTooBig,
  FileLocked,
  InvalidConfig,
}