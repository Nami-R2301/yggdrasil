package types;

import "core:c";

// Events holding relevant data during dispatch for user interaction with UI elements.
Event :: union {
  MouseEvent,
  KeyboardEvent
}

// Used for handling mouse click, hover, drag, and release events on UI elements rendered.
// Every UI element will be mapped to a box, used for mouse drag, and hover event dispatching.
MouseEvent :: struct {
  button:  Option(c.int),  // GLFW code.
  origin:  Dimension,
  end:     Dimension,
  width:   u16,
  height:  u16,
  frames:  u64,    // Duration in frames.
  node:    ^Node,  // Contains handler.
}

// Used for handling keys pressed, held, and released events on UI elements rendered.
KeyboardEvent :: struct {
  key:      c.int,  // GLFW code.
  frames:   u64,    // Duration in frames.
  node:     ^Node,  // Contains handler.
}

FileEvent :: struct {
  path:   string,
  name:   string,
  type:   FileType,
  ctx:    ^Context,  // Which tree to link these assets with.
}
