package types;

import "core:container/queue";

Renderer :: struct {
  node_queue:   queue.Queue(Node),
  vbos:         [dynamic]u8,
  vaos:         [dynamic]u8,
  ibos:         [dynamic]u8,
  framebuffers: [dynamic]u8,
  textures:     [dynamic]u8
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
