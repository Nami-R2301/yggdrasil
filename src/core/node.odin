package core;

import "core:fmt";

// Low-level API to create a custom UI node, to be attached onto the tree later on. This is normally intended to be abstracted away from the programmer
// behind high-level API entrypoints like 'begin_node'. One might use this function to wait and prevent the automatic rendering mechanisms provided
// and performed by 'begin_node', i.e. for a temporary node that does not live long enough to reach end of frame (Cleaned up with 'destroy_node(...)').
//
// Another common use-case would be to use this newly-created node from this function to only store and hold information that might happen within a cycle,
// without expanding the tree unnecessarily (data-nodes).
//
// @lifetime:           This function does NOT cleanup after itself like the high-level API, hence 'destroy_node(..)' is needed for each corresponding 'create_node' in the frame's scope.
// @param ctx:          The tree containing all nodes to be processed.
// @param id:           Unique identifier to lookup node when processing.
// @param tag:          Which tag identifier will be used to lookup the node in the map. Tag needs to be unique, unless you are planning to override the existing node.
// @param style:        CSS-like style mapping to be applied upon rendering on each frame.
// @param properties:   Data map to store information related to the node as well as override default ones (alt, disabled, type, etc...) which will mutate the node's functionality.
// @param children:     The leaf nodes related under this one,
create_node :: proc (ctx: ^Context, id: u16, tag: string, parent: Option(Node), style: map[u16]Option(any) = {}, properties: map[u16]Option(any) = {}, children: map[u16]Option(Node) = {}) -> (error: Error, node: Option(Node)) {
    if ctx.debug_level >= DebugLevel.Verbose {
      fmt.printfln("[INFO]:\t| Creating node '{}' [{}]...", tag, id);
    }

    node_opt := find_node(ctx, id);
    if is_some(node_opt) {
      return Error.DuplicateId, none(Node);
    }

    parent: ^Node = is_some(parent) ? new_clone(unwrap(parent)) : ctx.root; 
    if ctx.debug_level >= DebugLevel.Verbose {
      fmt.printfln("[INFO]:\t --- Created node '%s' [%d] under '%s' [%d]", tag, id, parent != nil ? parent.tag : "nil", parent != nil ? parent.id : 0);
    }

    new_node := Node {
      parent = parent,
      id = id,
      tag = tag,
      children = children,
      style = style,
      properties = properties
    };

    if parent == nil {
      ctx.root = new_clone(new_node);
    }

    return Error.None, new_node;
}

destroy_node ::proc (ctx: ^Context, id: u16) -> Error {
  panic("Not Implemented");
}

// Low-level API to attach a node to the current ui tree. Benefit of this function over its high-level counterparts 'begin_node(...)' is the ability to explicitely
// have control over when this node gets queued in the rendering pipeline, in case you needed to delay rendering after pre-processing, since the former will queue the
// node immediately without any say in it. Once a node is attached this way, only 'detach_node(...)' can remove it from the pipeline and NOT its end_... counterpart
// like the high-level API.
//
// @param ctx:    The current tree where we want to attach this node to. 
// @param node:   Which node is to be added to the tree
attach_node :: proc (ctx: ^Context, node: Node, to: Option(u16)) -> Error {
  if ctx.debug_level >= DebugLevel.Verbose {
    fmt.printfln("[INFO]:\t| Attaching '{}' [{}] to context tree", node.tag, node.id);
  }

  if ctx == nil {
    return Error.UinitializedContext;
  }

  parent: ^Node = nil;
  if is_some(to) {
    wrapped_parent := find_node(ctx, unwrap(to));

    if !is_some(wrapped_parent) {
      if ctx.debug_level >= DebugLevel.Normal {
        fmt.eprintfln("[ERR]:\t  --- Error when attaching node '{}' [{}] into parent [{}]: Parent not found", node.tag, node.id, unwrap(to));
      }
      return Error.NodeNotFound;
    }

    parent = new_clone(unwrap(wrapped_parent));
  } else {
    parent = is_some(ctx.last_node) ? new_clone(unwrap(ctx.last_node)) : ctx.root;
  }
  
  parent.children[node.id] = some(node);
  ctx.last_node = some(node);
  
  if ctx.debug_level >= DebugLevel.Verbose {
    fmt.printfln("[INFO]:\t  --- Attached '{}' [{}] to context tree at '{}' [{}]...", node.tag, node.id, parent.tag, parent.id);
  }
  return Error.None
}

detach_node :: proc (ctx: ^Context, id: u16, from: Option(string)) -> (Option(Node), Error) {
  if ctx.debug_level >= DebugLevel.Verbose {
    fmt.printfln("[INFO]:\t| Detaching [{}] from context tree...", id);
  }

  if ctx == nil {
    return none(Node), Error.UinitializedContext;
  } 
  
  wrapped_node := find_node(ctx, id);
  if !is_some(wrapped_node) {
    return wrapped_node, Error.None;
  }
  
  node := unwrap(wrapped_node);
  parent := node.parent;

  if parent == nil {
    if ctx.debug_level >= DebugLevel.Verbose {
      fmt.printfln("[WARN]:\t  --- Cannot detach unattached parent node [{}], skipping...", id);
    }

    return none(Node), Error.None;
  }

  if parent != nil {
    parent.children[node.id] = none(Node);
  }

  if ctx.debug_level >= DebugLevel.Verbose {
    fmt.printfln("[INFO]:\t  --- Detached [{}] from '{}' [{}]", id, parent.tag, parent.id);
  }

  return wrapped_node, Error.None;
}

find_node :: proc (ctx: ^Context, id: u16) -> Option(Node) {
  panic("Not Implemented");
}


