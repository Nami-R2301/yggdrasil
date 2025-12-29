package immediate;

import fmt      "core:fmt";
import strings  "core:strings";
import queue    "core:container/queue";
import runtime  "base:runtime";

import ygg      "../";
import types    "../types";

begin_node :: proc "c" (
    ctx:        runtime.Context,
    tag:        string,
    is_inline:  bool = false,
    style:      map[string]types.Option(string) = {},
    indent: string = "  ") -> (types.Node, types.Error) {
    using types;

    context = ctx;

    ygg_ctx := cast(^Context)ctx.user_ptr;
    assert_contextless(ygg_ctx != nil, "[ERR]:\tCannot begin node: Context is nil. Did you forget to call 'create_context(...)' ?");

    node := ygg.create_node(ctx, tag = tag, style = style);

    if queue.len(ygg_ctx.node_pairs) > 0 {
        node.parent = queue.back_ptr(&ygg_ctx.node_pairs);
    }

    new_indent := strings.concatenate({indent, "  "}, context.temp_allocator);
    ygg.attach_node(ctx, node, indent = indent);

    queue.push(&ygg_ctx.node_pairs, node);
    if is_inline {
        error := end_node(ctx, node.tag);
        if error != NodeError.None {
            return {}, error;
        }
    }

    return node, NodeError.None;
}

end_node :: proc "c" (
    ctx: runtime.Context,
    tag: string,
    indent: string = "  ") -> types.NodeError {
    using types;

    context = ctx;

    ygg_ctx := cast(^Context)ctx.user_ptr;
    assert_contextless(ygg_ctx != nil, "[ERR]:\tCannot end node: Context is nil. Did you forget to call 'create_context(...)' ?");

    new_indent, _ := strings.concatenate({ indent, "  " }, context.temp_allocator);
    node_ptr      := ygg.find_node(ctx, tag, indent = new_indent);

    if node_ptr == nil {
        fmt.printfln("[ERR]:{}| Cannot end node: Node given is 'None' ({})", indent)
        return NodeError.InvalidNode;
    }

    // Add to rendering queue and pop from queue list at the same time.
    queue.pop_back(&ygg_ctx.node_pairs);
    return NodeError.None;
}

img :: proc "c" (
    ctx: runtime.Context,
    is_inline:  bool = false,
    style:      map[string]types.Option(string) = {}) -> (types.Node, types.Error) {
    panic_contextless("Unimplemented");
}

input :: proc "c" (
    ctx: runtime.Context,
    is_inline:  bool = false,
    style:      map[string]types.Option(string) = {}) -> (types.Node, types.Error) {
    panic_contextless("Unimplemented");
}

// High level API to create a h1-h9 node.
text :: proc "c" (
    ctx: runtime.Context,
    content:    string,
    is_inline:  bool = false,
    style:      map[string]types.Option(string) = {}) -> (types.Node, types.Error) {
    return begin_node(ctx, "title", is_inline, style);
}

video :: proc "c" (
    ctx: runtime.Context,
    is_inline:  bool = false,
    style:      map[string]types.Option(string) = {}) -> (types.Node, types.Error) {
    panic_contextless("Unimplemented");
}

