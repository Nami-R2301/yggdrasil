package immediate;

import glfw "vendor:glfw";
import queue "core:container/queue";

import rt "../retained";
import types "../types";

begin_frame :: proc (ctx: ^types.Context) {
    assert(ctx != nil, "[ERR]:\t| Error beginning frame: Context is nil!");

    queue.init(&ctx.node_pairs);

    if ctx.renderer != nil {
        queue.init(&ctx.renderer.node_queue);
    }

    if ctx.window != nil {
        glfw.PollEvents();
    }
}

end_frame :: proc (ctx: ^types.Context) {
    assert(ctx != nil, "[ERR]:\t| Error ending frame: Context is nil!");
    assert(queue.len(ctx.node_pairs) == 0, "[ERR]:\t| Error ending frame: One or more nodes are not closed properly - did you add or forget some 'end_nodes(...)'?");

    if ctx.window != nil {
        glfw.SwapBuffers(ctx.window.glfw_handle);
    }

    if ctx.renderer != nil {
        queue.destroy(&ctx.renderer.node_queue);
    }

    // Cleanup queue & tree.
    for queue.len(ctx.node_pairs) > 0 {
        item := queue.pop_back(&ctx.node_pairs);
        rt.detach_node(ctx, item.id);
    }
    queue.destroy(&ctx.node_pairs);

    rt.detach_node(ctx, ctx.root.id);
    free(ctx.root);
    ctx.root = nil;
    ctx.last_node = nil;
}

