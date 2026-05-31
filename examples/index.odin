package examples;

import fmt "core:fmt";
import mem "core:mem";

// This file contains all examples in the same order as their numerical prefixes. Remove or comment any example you wish
// to strip them from the example binary.

main :: proc () {
    track: mem.Tracking_Allocator;
    mem.tracking_allocator_init(&track, context.allocator);
    mem.tracking_allocator_init(&track, context.temp_allocator);
    context.allocator      = mem.tracking_allocator(&track);
    context.temp_allocator = mem.tracking_allocator(&track);

    defer {
        if len(track.allocation_map) > 0 {
            fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
            for _, entry in track.allocation_map {
                fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location);
            }
        }
        mem.tracking_allocator_destroy(&track);
    }

    //hello_immediate();
    hello_retained();
}
