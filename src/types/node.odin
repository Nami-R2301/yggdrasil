package types;

Node :: struct {
  parent:     ^Node,
  id:         Id,
  tag:        string,
  children:   map[Id]Node,
  style:      map[string]Option(string),
  user_data:  rawptr,
}

NodeError :: enum u8 {
  None = 0,
  DuplicateId,
  NodeNotFound,
  MaxIdReached,
  InvalidNode
}
