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
create_node :: proc (ctx: ^Context, id: u16, tag: string, parent: Option(^Node) = nil, style: map[u16]Option(any) = {}, properties: map[u16]Option(any) = {}, children: map[u16]Option(Node) = {}) -> Node {
    assert(ctx != nil, "[ERR]:\t| Error creating node: Context is nil!");

    if ctx.debug_level >= DebugLevel.Verbose {
      fmt.printfln("[INFO]:\t| Creating node '{}' [{}]...", tag, id);
    }

    parent: ^Node = unwrap_or(parent, ctx.root); 
    if ctx.debug_level >= DebugLevel.Verbose {
      fmt.printfln("[INFO]:\t --- Created node '%s' [%d] under '%s' [%d]", tag, id, parent != nil ? parent.tag : "nil", parent != nil ? parent.id : 0);
    }

    node := Node {
      parent = parent,
      id = id,
      tag = tag,
      children = children,
      style = style,
      properties = properties
    };

    if parent == nil {
      ctx.root = new_clone(node);
    }

    return node;
}

reset_node :: proc (ctx: ^Context, id: u16) -> Error {
  assert(ctx != nil, "[ERR]:\t| Error resetting node: Context is nil!");
  panic("Not Implemented");
}

destroy_node :: proc (ctx: ^Context, id: u16) -> Error {
  assert(ctx != nil, "[ERR]:\t| Error destroying node: Context is nil!");

  node_opt := find_node(ctx, id);
  if !is_some(node_opt) {
    if ctx.debug_level >= DebugLevel.Normal {
      fmt.eprintfln("[ERR]:\t  --- Error destroying node: Node [{}] not found", id);
    }
    return Error.NodeNotFound;
  }

  node := unwrap(node_opt);
  if node.parent == ctx.root {
    free(node.parent);
  }

  // Add garbage indicator to avoid reading garbage.
  node.parent     = nil;
  node.tag        = "N/A";
  node.style      = {};
  node.properties = {};
  node.children   = {};
  
  if ctx.debug_level >= DebugLevel.Verbose {
    fmt.printfln("[INFO]:\t  --- Destroyed node [{}] and its children", id)
  }

  return Error.None;
}


find_node :: proc (ctx: ^Context, id: u16) -> Option(Node) {
  assert(ctx != nil, "[ERR]:\t| Error finding node: Context is nil!");

  if ctx.root == nil {
    return none(Node);
  }

  if id == ctx.root.id {
    return some(ctx.root^);
  }

  return _find_node(some(ctx.root^), id);
}

_find_node :: proc (current_node_opt: Option(Node), id: u16) -> Option(Node) {
  if is_some(current_node_opt) {
    current_node := unwrap(current_node_opt);
    for child_id, &child_opt in current_node.children {
      if child_id == id {
        return child_opt;
      }

      child := unwrap(child_opt);
      if len(child.children) > 0 {
        inner_node := _find_node(child_opt, id);
        if is_some(inner_node) {
          return inner_node;
        }
      }
    }
  }

  return none(Node);
}

get_tree_depth :: proc (root: ^Node) -> u16 {
  if root == nil {
    return 0;
  }

  depth: u16 = u16(len(root.children));  

  for id, &leaf_opt in root.children {
    if is_some(leaf_opt) {
      leaf := unwrap(leaf_opt);
      depth += get_tree_depth(&leaf);
    }
  }

  return depth;
}

// Low-level API to attach a node to the current ui tree. Benefit of this function over its high-level counterparts 'begin_node(...)' is the ability to explicitely
// have control over when this node gets queued in the rendering pipeline, in case you needed to delay rendering after pre-processing, since the former will queue the
// node immediately without any say in it. Once a node is attached this way, only 'detach_node(...)' can remove it from the pipeline and NOT its end_... counterpart
// like the high-level API.
//
// @param ctx:    The current tree where we want to attach this node to. 
// @param node:   Which node is to be added to the tree
attach_node :: proc (ctx: ^Context, node: Node) -> Error {
  assert(ctx != nil, "[ERR]:\t| Error attaching node: Context is nil!");
  
  if ctx.debug_level >= DebugLevel.Verbose {
    fmt.printfln("[INFO]:\t| Attaching '{}' [{}] to context tree", node.tag, node.id);
  }

  parent: ^Node = node.parent;
  if parent != nil  {
    parent_opt := find_node(ctx, node.parent.id);

    if !is_some(parent_opt) {
      if ctx.debug_level >= DebugLevel.Normal {
        fmt.eprintfln("[ERR]:\t  --- Error when attaching node '{}' [{}] into parent '{}' [{}]: Parent not found", node.tag, node.id, node.parent.tag, node.parent.id);
      }
      return Error.NodeNotFound;
    }
  } else {
    parent = ctx.last_node != nil ? ctx.last_node : ctx.root;
  }
  
  parent.children[node.id] = some(node);
  free(ctx.last_node);
  ctx.last_node = new_clone(node);
  
  if ctx.debug_level >= DebugLevel.Verbose {
    fmt.printfln("[INFO]:\t  --- Attached '{}' [{}] to context tree at '{}' [{}]...", node.tag, node.id, parent.tag, parent.id);
  }
  return Error.None
}

detach_node :: proc (ctx: ^Context, id: u16) -> Option(Node) { 
  assert(ctx != nil, "[ERR]:\t| Error detaching node: Context is nil!");
  
  if ctx.debug_level >= DebugLevel.Verbose {
    fmt.printfln("[INFO]:\t| Detaching [{}] from context tree...", id);
  }
  
  node_opt := find_node(ctx, id);
  if !is_some(node_opt) {
   return none(Node);
  }
  
  node := unwrap(node_opt);

  if node.parent == nil {
    if ctx.debug_level >= DebugLevel.Verbose {
      fmt.printfln("[WARN]:\t  --- Cannot detach unattached parent node [{}], skipping...", id);
    }

    return none(Node);
  }

  destroy_node(ctx, id);

  if ctx.debug_level >= DebugLevel.Verbose {
    fmt.printfln("[INFO]:\t  --- Detached [{}] from '{}' [{}]", id, node.parent.tag, node.parent.id);
  }

  return node;
}

