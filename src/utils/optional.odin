package utils;

import types "../types";

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////// OPTIONAL TYPE HELPER ////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////

some :: proc "contextless" (value: $T) -> types.Option(T) {
  return value;
}

none :: proc "contextless" ($T: typeid) -> types.Option(T) {
  return nil;
}

is_some :: proc "contextless" (opt: types.Option($T)) -> bool {
  #partial switch _ in opt {
    case T:     return true;
    case nil:  return false;
  }
  return false;
}

unwrap :: proc (opt: types.Option($T)) -> T {
  #partial switch value in opt {
    case T:       return value;
    case rawptr:  panic("Unwrapping a None Value");
    case nil:     panic("Unwrapping a None value");
  }

  return T{};  // Unreachable
}

unwrap_or :: proc "contextless" (opt: types.Option($T), default: T) -> T {
  switch value in opt {
    case T:        return value;
    case rawptr:   return default;
    case nil:      return default;
  }

  return default;
}
