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
  program:      Program,
  state:        RendererState,
  vbo:          Buffer,
  vao:          Buffer,
  ibo:          Buffer,
  ubos:         [dynamic]Buffer,
  framebuffers: [dynamic]Buffer,
  textures:     [dynamic]Buffer,
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

RendererType :: enum u8 {
  OpenGL = 0,
  Vulkan = 1
}

AsyncErrorMessage :: struct {
  type:         string,
  severity:     string,
  description:  cstring,
  code:         u32
}