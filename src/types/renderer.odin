package types;

import queue "core:container/queue";

Renderer :: struct {
  node_queue:   queue.Queue(Node),
  vbo:          Buffer,
  vao:          Buffer,
  ibo:          Buffer,
  ubos:         [dynamic]Buffer,
  framebuffers: [dynamic]Buffer,
  textures:     [dynamic]Buffer,
}

RendererError :: enum u8 {
  None = 0,
  InvalidAPI,
  InvalidBinding,
  InitError,
  UnsupportedVersion,
}

RendererType :: enum u8 {
  OpenGL = 0,
  Vulkan = 1
}