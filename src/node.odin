package yggdrasil;

import "core:fmt";

import types "types";
import utils "utils";



////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////// HIGH LEVEL API /////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////



////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////// LOW LEVEL API //////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////

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
_create_node :: proc (ctx: ^types.Context, id: u16, tag: string, parent: types.Option(^types.Node) = nil, style: map[u16]types.Option(any) = {}, properties: map[u16]types.Option(any) = {}, children: map[u16]types.Option(types.Node) = {}) -> types.Node {
    assert(ctx != nil, "[ERR]:\t| Error creating node: Context is nil!");

    if ctx.debug_level >= types.DebugLevel.Verbose {
      fmt.printfln("[INFO]:\t| Creating node '{}' [{}]...", tag, id);
    }

    parent: ^types.Node = utils.unwrap_or(parent, ctx.root); 
    if ctx.debug_level >= types.DebugLevel.Verbose {
      fmt.printfln("[INFO]:\t --- Created node '%s' [%d] under '%s' [%d]", tag, id, parent != nil ? parent.tag : "nil", parent != nil ? parent.id : 0);
    }

    node := types.Node {
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

_reset_node :: proc (ctx: ^types.Context, id: u16) -> types.ContextError {
  assert(ctx != nil, "[ERR]:\t| Error resetting node: Context is nil!");
  panic("Not Implemented");
}

_destroy_node :: proc (ctx: ^types.Context, id: u16) -> types.ContextError {
  assert(ctx != nil, "[ERR]:\t| Error destroying node: Context is nil!");

  node_opt := _find_node(ctx, id);
  if !utils.is_some(node_opt) {
    if ctx.debug_level >= types.DebugLevel.Normal {
      fmt.eprintfln("[ERR]:\t  --- Error destroying node: types.Node [{}] not found", id);
    }
    return types.ContextError.NodeNotFound;
  }

  node := utils.unwrap(node_opt);
  if node.parent == ctx.root {
    free(node.parent);
  }

  // Add garbage indicator to avoid reading garbage.
  node.parent     = nil;
  node.tag        = "N/A";
  node.style      = {};
  node.properties = {};
  node.children   = {};
  
  if ctx.debug_level >= types.DebugLevel.Verbose {
    fmt.printfln("[INFO]:\t  --- Destroyed node [{}] and its children", id)
  }

  return types.ContextError.None;
}


_find_node :: proc (ctx: ^types.Context, id: u16) -> types.Option(types.Node) {
  assert(ctx != nil, "[ERR]:\t| Error finding node: Context is nil!");

  if ctx.root == nil {
    return utils.none(types.Node);
  }

  if id == ctx.root.id {
    return utils.some(ctx.root^);
  }

  return _find_child(utils.some(ctx.root^), id);
}

@(private)
_find_child :: proc (current_node_opt: types.Option(types.Node), id: u16) -> types.Option(types.Node) {
  if utils.is_some(current_node_opt) {
    current_node := utils.unwrap(current_node_opt);
    for child_id, &child_opt in current_node.children {
      if child_id == id {
        return child_opt;
      }

      child := utils.unwrap(child_opt);
      if len(child.children) > 0 {
        inner_node := _find_child(child_opt, id);
        if utils.is_some(inner_node) {
          return inner_node;
        }
      }
    }
  }

  return utils.none(types.Node);
}

_get_tree_depth :: proc (root: ^types.Node) -> u16 {
  if root == nil {
    return 0;
  }

  depth: u16 = u16(len(root.children));  

  for id, &leaf_opt in root.children {
    if utils.is_some(leaf_opt) {
      leaf := utils.unwrap(leaf_opt);
      depth += _get_tree_depth(&leaf);
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
_attach_node :: proc (ctx: ^types.Context, node: types.Node) -> types.ContextError {
  assert(ctx != nil, "[ERR]:\t| Error attaching node: Context is nil!");
  
  if ctx.debug_level >= types.DebugLevel.Verbose {
    fmt.printfln("[INFO]:\t| Attaching '{}' [{}] to context tree", node.tag, node.id);
  }

  parent: ^types.Node = node.parent;
  if parent != nil  {
    parent_opt := _find_node(ctx, node.parent.id);

    if !utils.is_some(parent_opt) {
      if ctx.debug_level >= types.DebugLevel.Normal {
        fmt.eprintfln("[ERR]:\t  --- Error when attaching node '{}' [{}] into parent '{}' [{}]: Parent not found", node.tag, node.id, node.parent.tag, node.parent.id);
      }
      return types.ContextError.NodeNotFound;
    }
  } else {
    parent = ctx.last_node != nil ? ctx.last_node : ctx.root;
  }
  
  parent.children[node.id] = utils.some(node);
  free(ctx.last_node);
  ctx.last_node = new_clone(node);
  
  if ctx.debug_level >= types.DebugLevel.Verbose {
    fmt.printfln("[INFO]:\t  --- Attached '{}' [{}] to context tree at '{}' [{}]...", node.tag, node.id, parent.tag, parent.id);
  }
  return types.ContextError.None
}

_detach_node :: proc (ctx: ^types.Context, id: u16) -> types.Option(types.Node) { 
  assert(ctx != nil, "[ERR]:\t| Error detaching node: Context is nil!");
  
  if ctx.debug_level >= types.DebugLevel.Verbose {
    fmt.printfln("[INFO]:\t| Detaching [{}] from context tree...", id);
  }
  
  node_opt := _find_node(ctx, id);
  if !utils.is_some(node_opt) {
   return utils.none(types.Node);
  }
  
  node := utils.unwrap(node_opt);

  if node.parent == nil {
    if ctx.debug_level >= types.DebugLevel.Verbose {
      fmt.printfln("[WARN]:\t  --- Cannot detach unattached parent node [{}], skipping...", id);
    }

    return utils.none(types.Node);
  }

  _destroy_node(ctx, id);

  if ctx.debug_level >= types.DebugLevel.Verbose {
    fmt.printfln("[INFO]:\t  --- Detached [{}] from '{}' [{}]", id, node.parent.tag, node.parent.id);
  }

  return node;
}

