#include <stdio.h>
#include <stdint.h>
#include "types.h"

extern Window ygg_create_window(
    const char* title,
    const char* profile,
    unsigned int width,
    unsigned int height,
    unsigned char gl_major,
    unsigned char gl_minor,
    Maybe refresh_rate,
    const char* indent);

extern bool ygg_is_window_running(Window* window_ptr);
extern void ygg_swap_buffers(Window* window_ptr);
extern void ygg_poll_events(Window* window_ptr);
extern WindowError ygg_destroy_window(Window* window_ptr, const char* indent);

extern Renderer ygg_create_renderer(Window* window, const char* indent);
extern RendererError ygg_destroy_renderer(Renderer* renderer_ptr, const char* indent);

int main(void)
{
    uint32_t offset[2] = {0, 0};
    int32_t gl_version[2] = {4, 3};
    Maybe refresh_rate = {};

    Window test  = ygg_create_window("Call from C", "debug", 800, 600, 4, 3, refresh_rate, "  ");
    Renderer gl  = ygg_create_renderer(&test, "  ");

    while (ygg_is_window_running(&test))
    {
        ygg_poll_events(&test);
        ygg_swap_buffers(&test);
    }

    if (ygg_destroy_renderer(&gl, "  ")) return 1;
    if (ygg_destroy_window(&test, "  ")) return 1;
    return 0;
}