package immediate;

import runtime  "base:runtime";
import queue    "core:container/queue";

import core   "..";
import types "../types";

begin_frame :: proc "c" (ctx: runtime.Context) {
    using types;

    context = ctx;
    core_ctx := cast(^Context)ctx.user_ptr;
    assert_contextless(core_ctx != nil, "[ERR]:\tCannot begin frame: Context is nil. Did you forget to call 'create_context(...)' ?");

    queue.init(&core_ctx.node_pairs);

    if core_ctx.renderer != nil {
        queue.init(&core_ctx.renderer.node_queue);
    }
}

end_frame :: proc "c" (ctx: runtime.Context) {
    using types;

    context = ctx;
    core_ctx := cast(^Context)ctx.user_ptr;
    assert_contextless(core_ctx != nil, "[ERR]:\tCannot end frame: Context is nil. Did you forget to call 'create_context(...)' ?");

    assert_contextless(queue.len(core_ctx.node_pairs) == 0, "[ERR]:\tCannot end frame: One or more nodes are not closed properly. " +
    "Did you add or forget some matching 'end_nodes(...)' to your 'begin_nodes(...)' ?");

    if core_ctx.renderer != nil {
        core.render_now(core_ctx.window.dimensions, core_ctx.renderer.pipeline);
        queue.destroy(&core_ctx.renderer.node_queue);
    }

    // Cleanup queue & tree.
    for queue.len(core_ctx.node_pairs) > 0 {
        item := queue.pop_back(&core_ctx.node_pairs);
        core.detach_node(ctx, item.id);
    }
    queue.destroy(&core_ctx.node_pairs);

    core.detach_node(ctx, core_ctx.root.id);
    free(core_ctx.root, ctx.allocator);
    core_ctx.root = nil;
    core_ctx.last_node = nil;
}

