//
// Created by Nami on 12/30/25.
//

#ifndef YGGDRASIL_TYPES_H
#define YGGDRASIL_TYPES_H

typedef struct
{
  void *value;
  bool has_value;
} Option;

typedef enum {
  NoLogs     = 0,
  Normal     = 1,
  Verbose    = 2,
  Everything = 3
} LogLevel;

typedef struct {
  void *procedure;
  void *context;
} Allocator;

typedef struct {
  void* data;
  uint64_t len;
  uint64_t cap;
  Allocator allocator;
} Array;

typedef struct {
  void *data;
  uint64_t len;
  Allocator allocator;
} Map;

typedef enum {
  None = 0,
  InvalidContext,
  IDOverflow,
  UinitializedContext,
  HeadlessMode,  // When the user tries to create or use a window when they are in headless mode.
  ArenaAllocFailed  // If our arena can't reserve the 1GB of memory for the ctx for some reason
} ContextError;

typedef struct {
  void* glfw_handle;
  const char* title;
  uint32_t width;
  uint32_t height;
  uint32_t offset[2];
  uint8_t gl_version[2];
  uint16_t refresh_rate;
} Window_c;

typedef enum {
  NoWindowError = 0,
  InitWindowError,
  InvalidWindow
} WindowError;

typedef enum {
  Vbo = 0,
  Vao,
  Framebuffer,
} BufferType;

typedef struct {
  uint32_t attachments_opt[2];
  uint64_t count;
  uint64_t length;
  uint64_t capacity;
  uint32_t id;
  BufferType type;
} Buffer_c;

typedef uint32_t Program;

typedef struct {
  Buffer_c vao;
  Buffer_c vbo;
  Buffer_c framebuffer;
  Program program;
} BufferPipeline;

typedef enum {
  NotInit = 0,
  Initialized,
  Prepared,
  Destroyed
} RendererState;

typedef enum {
  NoRendererError = 0,
  InvalidRenderer,
  InvalidAPI,
  InvalidBinding,
  InitRendererError,
  APIError,
  UnsupportedVersion,
  InvalidUserData
} RendererError;

typedef struct {
  Array textures;
  BufferPipeline pipeline;
  RendererState state;
} Renderer_c;

typedef struct
{
  void *parent;
  const char *tag;
  void *children;
  void *style;
  void *user_data;
  void *id;
} Node_c;

typedef struct
{
  Renderer_c *renderer;
  Window_c *window;
  Node_c *root;
  Node_c *last_node;
  Map config;

  // Internal [7 fields] //
} Context_c;

#endif //YGGDRASIL_TYPES_H