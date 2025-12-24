package immediate;

import fmt      "core:fmt";
import strings  "core:strings";
import queue    "core:container/queue";

import rt       "../retained";
import ygg      "../";
import types    "../types";

begin_node :: proc (
    tag:        string,
    is_inline:  bool = false,
    style:      map[string]types.Option(string) = {},
    indent: string = "  ") -> (types.Node, types.Error) {
    using types;

    assert(context.user_ptr != nil, "[ERR]:\t| Error creating node: Context is nil!");
    ctx: ^Context = cast(^Context)context.user_ptr;

    node, error := rt.create_node(tag = tag, style = style);

    if error != ContextError.None {
        return node, error;
    }

    if queue.len(ctx.node_pairs) > 0 {
        node.parent = queue.back_ptr(&ctx.node_pairs);
    }

    new_indent := strings.concatenate({indent, "  "}, context.temp_allocator);
    node_error := rt.attach_node(node, indent = indent);

    if node_error != NodeError.None {
        fmt.printfln("[ERR]:{}--- Error beginning node '{}': Cannot attach node -> {}", indent, tag, node_error);
        return {}, node_error;
    }

    queue.push(&ctx.node_pairs, node);
    if is_inline {
        error := end_node(node.tag);
        if error != NodeError.None {
            return {}, error;
        }
    }

    return node, NodeError.None;
}

end_node :: proc (tag: string, indent: string = "  ") -> types.NodeError {
    using types;

    assert(context.user_ptr != nil, "[ERR]:\t| Error ending node: Context is nil!");
    ctx: ^Context = cast(^Context)context.user_ptr;

    new_indent, _ := strings.concatenate({ indent, "  " }, context.temp_allocator);
    node_ptr      := ygg.find_node(tag, indent = new_indent);

    if node_ptr == nil {
        fmt.printfln("[ERR]:{}| Error ending node: Node given is 'None' ({})", indent)
        return NodeError.InvalidNode;
    }

    // Add to rendering queue and pop from queue list at the same time.
    queue.pop_back(&ctx.node_pairs);
    return NodeError.None;
}

img :: proc (
    is_inline:  bool = false,
    style:      map[string]types.Option(string) = {}) -> (types.Node, types.Error) {
    panic("Unimplemented");
}

input :: proc (
    is_inline:  bool = false,
    style:      map[string]types.Option(string) = {}) -> (types.Node, types.Error) {
    panic("Unimplemented");
}

li :: proc (
    is_inline:  bool = false,
    style:      map[string]types.Option(string) = {}) -> (types.Node, types.Error) {
    panic("Unimplemented");
}

link :: proc (
    is_inline:  bool = false,
    style:      map[string]types.Option(string) = {}) -> (types.Node, types.Error) {

    return begin_node("link", is_inline, style);
}

meta :: proc (
    is_inline:  bool = false,
    style:      map[string]types.Option(string) = {}) -> (types.Node, types.Error) {
    panic("Unimplemented");
}

nav :: proc (
    is_inline:  bool = false,
    style:      map[string]types.Option(string) = {}) -> (types.Node, types.Error) {
    panic("Unimplemented");
}

ol :: proc (
    is_inline:  bool = false,
    style:      map[string]types.Option(string) = {}) -> (types.Node, types.Error) {
    panic("Unimplemented");
}

// High Level API to create and link a JS script.
script :: proc (
    is_inline:  bool = false,
    style:      map[string]types.Option(string) = {}) -> (types.Node, types.Error) {
    panic("Unimplemented");
}

// High level API to create a h1-h9 node.
text :: proc (
    str:       string,
    is_inline:  bool = false,
    style:      map[string]types.Option(string) = {}) -> (types.Node, types.Error) {
    return begin_node("title", is_inline, style);
}

ul :: proc (
    is_inline:  bool = false,
    style:      map[string]types.Option(string) = {}) -> (types.Node, types.Error) {
    panic("Unimplemented");
}

video :: proc (
    is_inline:  bool = false,
    style:      map[string]types.Option(string) = {}) -> (types.Node, types.Error) {
    panic("Unimplemented");
}

