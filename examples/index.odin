package examples;

import mem "core:mem";

// This file contains all examples in the same order as their numerical prefixes. Remove or comment any example you wish
// to strip them from the example binary.

main :: proc () {
    track: mem.Tracking_Allocator;
    mem.tracking_allocator_init(&track, context.allocator);
    defer mem.tracking_allocator_destroy(&track);

    context.allocator      = mem.tracking_allocator(&track)
    context.temp_allocator = mem.tracking_allocator(&track)
    defer free_all(context.temp_allocator);

    hello_immediate();
    hello_retained();
}