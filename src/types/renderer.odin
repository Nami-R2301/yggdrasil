package types;

Renderer :: struct {
  vbos: []u8,
  vaos: []u8,
  ibos: []u8,
  framebuffers: []u8,
  textures: []u8
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
