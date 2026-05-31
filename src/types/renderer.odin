package types;

Program :: u32;

ProgramError :: enum u8 {
  None = 0,
  InvalidShader,
  ProgramNotFound
}

Renderer :: struct {
  textures:     [dynamic]Buffer,
  pipeline:     BufferPipeline,
  state:        RendererState,
}

RendererState :: enum u8 {
  None = 0,
  Initialized,
  Prepared,
  Destroyed
}

BufferPipeline :: struct {
  vao:          Buffer,
  vbo:          Buffer,
  framebuffer:  Buffer,
  program:      Program,
  textures:     [dynamic]Buffer,
}

RendererError :: enum u8 {
  None = 0,
  InvalidRenderer,
  InvalidAPI,
  InvalidBinding,
  InitError,
  APIError,
  UnsupportedVersion,
  InvalidUserData
}

AsyncErrorMessage :: struct {
  type:         string,
  severity:     string,
  description:  cstring,
  code:         u32
}