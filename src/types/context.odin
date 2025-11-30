package types;

import "core:container/queue";

// NOTE: The u16 encoding limit for IDs is a deliberate choice, since I deemed this library far too unoptimized to 
// even fathom having more that 2^16 nodes in a tree at a time. Main bottlenecks here are searching and dispatching
// custom event handling on a per-node basis. So in theory, if anyone wants to extend this library and can address
// these concerns, just swap it with a higher encoding, since every core function dealing with node IDs uses this 
// type aliasing in case this needed to be changed.
Id :: u16;

Dimension :: [2]u16;

// Main data related to a tree used for keeping nodes of data either for rendering to a window or passing it to a vbo.
//
// ORDERING: I took the decision to keep the ordering of nodes sharing the same parent using IDs (ascending). Meaning,
// the assignment of IDs to your nodes is order sensitive and if you encounter misordering or certain nodes being 
// prioritized over others, you might have a non-ascending ID causing this.
Context :: struct {
  window:                   ^Window,
  root:                     ^Node,
  last_node:                ^Node,
  renderer:                 ^Renderer,
  node_pairs:               queue.Queue(Node),
  config:                   map[string]string,
  cursor:                   Dimension,
}

// Errors regarding the overall app context.
ContextError :: enum u8 {
  None = 0,
  InvalidContext,
  UinitializedContext,
  HeadlessMode,  // When the user tries to create or use a window when they are in headless mode.
}
