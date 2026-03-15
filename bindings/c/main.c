#include <stdio.h>
#include <stdint.h>
#include <assert.h>

#include "types.h"

extern Window_c ygg_create_window(
    const char *title,
    const char *profile,
    uint32_t width,
    uint32_t height,
    uint8_t gl_major,
    uint8_t gl_minor,
    uint32_t *refresh_rate_opt,
    const char *indent
);

extern bool ygg_is_window_running(Window_c* window_ptr);
extern void ygg_swap_buffers(Window_c* window_ptr);
extern void ygg_poll_events(Window_c* window_ptr);
extern WindowError ygg_destroy_window(Window_c* window_ptr, const char *indent);

extern Renderer_c ygg_create_renderer(Window_c* window, const char *indent);
extern RendererError ygg_destroy_renderer(Renderer_c* renderer_ptr, const char *indent);

// UTILS
extern void *ygg_some_i(int value);
extern bool ygg_is_some_i(void *value);
extern bool ygg_is_none(void *value);
extern void *ygg_unwrap(void *value);
extern void *ygg_unwrap_or(void *value, void *default_value);

extern Context_c* ygg_create_context(
    Window_c *window_ptr,
    Renderer_c *renderer_ptr,
    Map *config,
    const char *indent
);
extern void ygg_destroy_context(Context_c *ctx, const char *indent);

int main(void)
{
    void *refresh_rate_opt = ygg_some_i(60);
    assert(ygg_is_some_i(refresh_rate_opt));

    Window_c window = ygg_create_window("Testing", "debug", 800, 600, 4, 3, refresh_rate_opt, "  ");
    Renderer_c gl   = ygg_create_renderer(&window, "  ");
    Context_c *ctx  = ygg_create_context(&window, &gl, nullptr, "  ");

    printf("[C]\t | Window offset = (%d,%d)\n", window.offset[0], window.offset[1]);
    printf("[C]\t | Window dimensions = (%d,%d)\n", window.width, window.height);
    printf("[C]\t | Window OpenGL version = (%d,%d)\n", window.gl_version[0], window.gl_version[1]);
    printf("[C]\t | Window refresh rate = %d\n", window.refresh_rate);

    printf("[C]\t | Renderer textures: Size = %lu, Len = %lu, Data = %p\n", sizeof(gl.textures), gl.textures.len, gl.textures.data);
    printf("[C]\t | Renderer pipeline: Size = %lu, Vao = %d, Vbo = %d, Fbo = %d, Program = %d\n", sizeof(gl.pipeline), gl.pipeline.vao.id,
        gl.pipeline.vbo.id, gl.pipeline.framebuffer.id, gl.pipeline.program);
    printf("[C]\t | Renderer state = %d\n", gl.state);

    while (ygg_is_window_running(ctx->window))
    {
        ygg_poll_events(ctx->window);
        ygg_swap_buffers(ctx->window);
    }

    ygg_destroy_context(ctx, "  ");
    return 0;
}