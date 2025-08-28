package types;

import "vendor:glfw";

Node :: struct {
  parent: ^Node,
  id: u16,
  tag: string,
  children: map[u16]Option(Node),
  style: map[u16]Option(any),
  properties: map[u16]Option(any)
}
