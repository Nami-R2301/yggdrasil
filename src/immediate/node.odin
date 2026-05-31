package immediate;

import fmt      "core:fmt";
import strings  "core:strings";
import queue    "core:container/queue";

import ygg      "../";
import types    "../types";

@(export, link_prefix="ygg_im_")
begin_node :: proc "c" (
    ctx:        ^types.Context,
    tag:        string,
    is_inline:  bool = false,
    style:      map[string]Maybe(string) = {},
    indent: string = "  ") -> (types.Node, types.Error) {
    assert_contextless(ctx != nil, "[ERR]:\tCannot begin node: Context is nil. Did you forget to call 'create_context(...)' ?");
    context = ctx^._context;

    node := ygg.create_node(ctx, tag = tag, style = style);

    if queue.len(ctx.node_pairs) > 0 {
        node.parent = queue.back_ptr(&ctx.node_pairs);
    }

    new_indent := strings.concatenate({indent, "  "}, context.temp_allocator);
    c_indent := cstring(raw_data(new_indent));
    ygg.attach_node(ctx, node, indent = c_indent);

    queue.push(&ctx.node_pairs, node);
    if is_inline {
        error := end_node(ctx, node.tag);
        if error != types.NodeError.None {
            return {}, error;
        }
    }

    return node, types.NodeError.None;
}

@(export, link_prefix="ygg_im_")
end_node :: proc "c" (
    ctx:    ^types.Context,
    tag:    string,
    indent: string = "  ") -> types.NodeError {
    assert_contextless(ctx != nil, "[ERR]:\tCannot end node: Context is nil. Did you forget to call 'create_context(...)' ?");
    context = ctx^._context;

    new_indent, _ := strings.concatenate({ indent, "  " }, context.temp_allocator);
    c_indent      := cstring(raw_data(new_indent));
    node_ptr      := ygg.find_node(ctx, tag, indent = c_indent);

    if node_ptr == nil {
        fmt.printfln("[ERR]:{}| Cannot end node: Node given is 'None' ({})", indent)
        return types.NodeError.InvalidNode;
    }

    // Add to rendering queue and pop from queue list at the same time.
    queue.pop_back(&ctx.node_pairs);
    return types.NodeError.None;
}

@(export, link_prefix="ygg_im_")
img :: proc "c" (
    ctx:        ^types.Context,
    is_inline:  bool = false,
    style:      map[string]Maybe(string) = {}) -> (types.Node, types.Error) {
    panic_contextless("Unimplemented");
}

input :: proc "c" (
    ctx:        ^types.Context,
    is_inline:  bool = false,
    style:      map[string]Maybe(string) = {}) -> (types.Node, types.Error) {
    panic_contextless("Unimplemented");
}

// High level API to create a h1-h9 node.
@(export, link_prefix="ygg_im_")
text :: proc "c" (
    ctx:        ^types.Context,
    content:    string,
    is_inline:  bool = false,
    style:      map[string]Maybe(string) = {}) -> (types.Node, types.Error) {
    return begin_node(ctx, content, is_inline, style);
}

@(export, link_prefix="ygg_im_")
video :: proc "c" (
    ctx:        ^types.Context,
    is_inline:  bool = false,
    style:      map[string]Maybe(string) = {}) -> (types.Node, types.Error) {
    panic_contextless("Unimplemented");
}

