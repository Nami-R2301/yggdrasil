package types;

import queue "core:container/queue";

Program :: u32;

ProgramError :: enum u8 {
  None = 0,
  InvalidShader,
  ProgramNotFound
}

Renderer :: struct {
  node_queue:   queue.Queue(Node),
  textures:     [dynamic]Buffer,
  vao:          Buffer,
  vbo:          Buffer,
  framebuffer:  Buffer,
  program:      Program,
  state:        RendererState,
}

RendererState :: enum u8 {
  None = 0,
  Initialized,
  Prepared,
  Destroyed
}

RendererError :: enum u8 {
  None = 0,
  InvalidRenderer,
  InvalidAPI,
  InvalidBinding,
  InitError,
  APIError,
  UnsupportedVersion,
}

AsyncErrorMessage :: struct {
  type:         string,
  severity:     string,
  description:  cstring,
  code:         u32
}