package types;

Node :: struct {
  parent:     ^Node,
  id:         Id,
  tag:        string,
  children:   map[Id]Node,
  style:      map[string]Option(string),
  properties: map[string]Option(string)
}

NodeError :: enum u8 {
  None = 0,
  DuplicateId,
  NodeNotFound,
  MaxIdReached,
  InvalidNode
}
