package immediate;

import queue    "core:container/queue";

import core   "..";
import types "../types";

@(export, link_prefix="ygg_im_")
begin_frame :: proc "c" (ctx: ^types.Context) {
    assert_contextless(ctx != nil, "[ERR]:\tCannot begin frame: Context is nil. Did you forget to call 'create_context(...)' ?");
    context = ctx^._context;

    queue.init(&ctx.node_pairs);
}

@(export, link_prefix="ygg_im_")
end_frame :: proc "c" (ctx: ^types.Context) {
    assert_contextless(ctx != nil, "[ERR]:\tCannot end frame: Context is nil. Did you forget to call 'create_context(...)' ?");
    context = ctx^._context;

    assert_contextless(queue.len(ctx.node_pairs) == 0, "[ERR]:\tCannot end frame: One or more nodes are not closed properly. " +
    "Did you add or forget some matching 'end_nodes(...)' to your 'begin_nodes(...)' ?");

    if ctx.renderer != nil {
        vp: [2]u32 = ctx.window != nil ? {ctx.window.width, ctx.window.height} : {800, 600};
        core.render_now(vp, ctx.renderer.pipeline);
    }

    // Cleanup queue & tree.
    for queue.len(ctx.node_pairs) > 0 {
        item := queue.pop_back(&ctx.node_pairs);
        core.detach_node(ctx, item.id);
    }
    queue.destroy(&ctx.node_pairs);

    core.detach_node(ctx, ctx.root.id);
    free(ctx.root);
    ctx.root = nil;
}

