package utils;

import types "../types";

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////// OPTIONAL TYPE HELPER ////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////

some :: proc "c" (value: $T) -> types.Option(T) {
  return value;
}

none :: proc "c" ($T: typeid) -> types.Option(T) {
  return nil;
}

is_some :: proc "c" (opt: types.Option($T)) -> bool {
  #partial switch v in opt {
    case T:       return true;
    case rawptr:  return false;
    case nil:     return false;
  }
  return false  // Unreachable;
}

unwrap :: proc (opt: types.Option($T)) -> T {
  #partial switch value in opt {
    case T:       return value;
    case rawptr:  panic("Unwrapping a None Value");
    case nil:     panic("Unwrapping a None Value");
  }

  return T{};  // Unreachable
}

unwrap_or :: proc "c" (opt: types.Option($T), default: T) -> T {
  switch value in opt {
    case T:        return value;
    case rawptr:   return default;
  }

  return default;
}
