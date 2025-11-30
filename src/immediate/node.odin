package immediate;

import fmt "core:fmt";
import strings "core:strings";
import queue "core:container/queue";

import rt "../retained";
import helpers "../";
import types "../types";
import utils "../utils";

begin_node :: proc (
ctx:        ^types.Context,
tag:        string,
is_inline:  bool = false,
style:      map[string]types.Option(string) = {},
properties: map[string]types.Option(string) = {},
indent: string = "  ") -> types.Result(types.Node) {
    using types;

    assert(ctx != nil, "[ERR]:\t| Error creating node: Context is nil!");

    result: Result(Node) = { error = NodeError.None, opt = utils.none(Node) };
    result.opt = utils.some(rt.create_node(ctx, tag = tag, style = style, properties = properties));

    if result.error != NodeError.None {
        return result;
    }

    node := utils.unwrap(result.opt);

    if queue.len(ctx.node_pairs) > 0 {
        node.parent = queue.back_ptr(&ctx.node_pairs);
    }

    new_indent := strings.concatenate({indent, "  "});
    error := rt.attach_node(ctx, node, indent);
    delete_string(new_indent);

    if error != NodeError.None {
        fmt.printfln("[ERR]:{}--- Error beginning node '{}': Cannot attach node -> {}", indent, tag, error);
        return { error, utils.none(Node) };
    }

    queue.push(&ctx.node_pairs, node);
    if is_inline {
        error := end_node(ctx, node.tag);
        if error != NodeError.None {
            return { error, utils.none(Node) };
        }
    }

    return result;
}

end_node :: proc (ctx: ^types.Context, tag: string, indent: string = "  ") -> types.NodeError {
    using types;

    assert(ctx != nil, "[ERR]:\t| Error ending node: Context is nil!");
    new_indent, _ := strings.concatenate({ indent, "  " });
    node_ptr := helpers.find_node(ctx, tag, indent = new_indent);
    delete_string(new_indent);

    if node_ptr == nil {
        fmt.printfln("[ERR]:{}| Error ending node: Node given is 'None' ({})", indent, #location())
        return NodeError.InvalidNode;
    }

    // Add to rendering queue and pop from queue list at the same time.
    queue.pop_back(&ctx.node_pairs);
    return NodeError.None;
}

root :: proc (
ctx:        ^types.Context,
style:      map[string]types.Option(string) = {},
properties: map[string]types.Option(string) = {}) -> types.Result(types.Node) {
    assert(ctx != nil, "[ERR]:\t| Error ending node: Context is nil!");

    return begin_node(ctx, "root", false, style, properties);
}

head :: proc (
ctx:        ^types.Context,
is_inline:  bool = false,
style:      map[string]types.Option(string) = {},
properties: map[string]types.Option(string) = {}) -> types.Result(types.Node) {
    assert(ctx != nil, "[ERR]:\t| Error ending node: Context is nil!");

    return begin_node(ctx, "head", is_inline, style, properties);
}

img :: proc (
ctx:        ^types.Context,
is_inline:  bool = false,
style:      map[string]types.Option(string) = {},
properties: map[string]types.Option(string) = {}) -> types.Result(types.Node) {
    panic("Unimplemented");
}

input :: proc (
ctx:        ^types.Context,
is_inline:  bool = false,
style:      map[string]types.Option(string) = {},
properties: map[string]types.Option(string) = {}) -> types.Result(types.Node) {
    panic("Unimplemented");
}

li :: proc (
ctx:        ^types.Context,
is_inline:  bool = false,
style:      map[string]types.Option(string) = {},
properties: map[string]types.Option(string) = {}) -> types.Result(types.Node) {
    panic("Unimplemented");
}

link :: proc (
ctx:        ^types.Context,
is_inline:  bool = false,
style:      map[string]types.Option(string) = {},
properties: map[string]types.Option(string) = {}) -> types.Result(types.Node) {
    assert(ctx != nil, "[ERR]:\t| Error ending node: Context is nil!");

    return begin_node(ctx, "link", is_inline, style, properties);
}

meta :: proc (
ctx:        ^types.Context,
is_inline:  bool = false,
style:      map[string]types.Option(string) = {},
properties: map[string]types.Option(string) = {}) -> types.Result(types.Node) {
    panic("Unimplemented");
}

nav :: proc (
ctx:        ^types.Context,
is_inline:  bool = false,
style:      map[string]types.Option(string) = {},
properties: map[string]types.Option(string) = {}) -> types.Result(types.Node) {
    panic("Unimplemented");
}

ol :: proc (
ctx:        ^types.Context,
is_inline:  bool = false,
style:      map[string]types.Option(string) = {},
properties: map[string]types.Option(string) = {}) -> types.Result(types.Node) {
    panic("Unimplemented");
}

p :: proc (
ctx:        ^types.Context,
is_inline:  bool = false,
style:      map[string]types.Option(string) = {},
properties: map[string]types.Option(string) = {}) -> types.Result(types.Node) {
    panic("Unimplemented");
}

// High Level API to create and link a JS script.
script :: proc (
ctx:        ^types.Context,
is_inline:  bool = false,
style:      map[string]types.Option(string) = {},
properties: map[string]types.Option(string) = {}) -> types.Result(types.Node) {
    panic("Unimplemented");
}

span :: proc (
ctx:        ^types.Context,
is_inline:  bool = false,
style:      map[string]types.Option(string) = {},
properties: map[string]types.Option(string) = {}) -> types.Result(types.Node) {
    panic("Unimplemented");
}

table :: proc (
ctx:        ^types.Context,
is_inline:  bool = false,
style:      map[string]types.Option(string) = {},
properties: map[string]types.Option(string) = {}) -> types.Result(types.Node) {
    panic("Unimplemented");
}

td ::proc (
ctx:        ^types.Context,
is_inline:  bool = false,
style:      map[string]types.Option(string) = {},
properties: map[string]types.Option(string) = {}) -> types.Result(types.Node) {
    panic("Unimplemented");

}

th ::proc (
ctx:        ^types.Context,
is_inline:  bool = false,
style:      map[string]types.Option(string) = {},
properties: map[string]types.Option(string) = {}) -> types.Result(types.Node) {
    panic("Unimplemented");
}

tr :: proc (
ctx:        ^types.Context,
is_inline:  bool = false,
style:      map[string]types.Option(string) = {},
properties: map[string]types.Option(string) = {}) -> types.Result(types.Node) {
    panic("Unimplemented");

}

// High level API to create a h1-h9 node.
title :: proc (
ctx:        ^types.Context,
text:       string,
is_inline:  bool = false,
style:      map[string]types.Option(string) = {},
properties: map[string]types.Option(string) = {}) -> types.Result(types.Node) {
    assert(ctx != nil, "[ERR]:\t| Error ending node: Context is nil!");

    return begin_node(ctx, "title", is_inline, style, properties);
}

ul :: proc (
ctx:        ^types.Context,
is_inline:  bool = false,
style:      map[string]types.Option(string) = {},
properties: map[string]types.Option(string) = {}) -> types.Result(types.Node) {
    panic("Unimplemented");
}

video :: proc (
ctx:        ^types.Context,
is_inline:  bool = false,
style:      map[string]types.Option(string) = {},
properties: map[string]types.Option(string) = {}) -> types.Result(types.Node) {
    panic("Unimplemented");
}

