package types;

import "vendor:glfw";

Node :: struct {
  parent:     ^Node,
  id:         Id,
  tag:        string,
  children:   map[Id]^Node,
  style:      map[Id]Option(string),
  properties: map[Id]Option(string)
}
