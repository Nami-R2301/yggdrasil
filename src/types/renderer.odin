package types;

Renderer :: struct {
  vbos: []u8,
  vaos: []u8,
  ibos: []u8,
  framebuffers: []u8,
  textures: []u8
}

RendererError :: enum {
  None,
  InvalidAPI,
  InvalidBinding,
  InitError,
  UnsupportedVersion,
}

RendererType :: enum u8 {
  OpenGL = 0,
  Vulkan = 1
}
