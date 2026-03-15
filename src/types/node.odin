package types;

Node :: struct {
  parent:     ^Node,
  children:   map[Id]Node,
  style:      map[string]Maybe(string),
  user_data:  rawptr,
  tag:        string,
  id:         Id,
}

Node_c :: struct #packed {
  parent:     ^Node_c,
  children:   rawptr,
  style:      rawptr,
  user_data:  rawptr,
  tag:        cstring,
  id:         Id,
}

NodeError :: enum u8 {
  None = 0,
  DuplicateId,
  NodeNotFound,
  MaxIdReached,
  InvalidNode
}
