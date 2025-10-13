package types;

// Aggregate all errors into this type when a procedure might return multiple types of errors.
Error :: union {
  ContextError,
  NodeError,
  WindowError,
  RendererError,
  ConfigError,
  BufferError
}


// Rust-like optional type in odin.
Option :: union ($T: typeid) {
  T,
  rawptr
}

Result :: struct ($T: typeid) {
  error:  Error,
  opt:    Option(T)
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
