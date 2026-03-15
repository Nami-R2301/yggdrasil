package utils;

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////// OPTIONAL TYPE HELPER ////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////

is_some :: proc "contextless" (opt: Maybe($T)) -> bool {
  return opt != nil;
}

is_none :: proc "contextless" (opt: Maybe($T)) -> bool {
  return !is_some(opt);
}

unwrap :: proc "contextless" (opt: Maybe($T)) -> T {
  switch value in opt {
    case T: return value;
    case:   panic_contextless("Unwrapping a None Value");
  }

  panic_contextless("Unreachable");
}

unwrap_or :: proc "contextless" (opt: Maybe($T), default: T) -> T {
  switch value in opt {
    case T: return value;
    case:   return default;
  }

  panic_contextless("Unreachable");
}


//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////// C BINDINGS ///////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////

@(export, link_name="ygg_some_c", require_results)
some_char :: proc "c" (value: i8) -> Maybe(i8) {
  return value;
}

@(export, link_name="ygg_some_i", require_results)
some_int :: proc "c" (value: i32) -> Maybe(i32) {
  return value;
}

@(export, link_name="ygg_some_f", require_results)
some_float :: proc "c" (value: f32) -> Maybe(f32) {
  return value;
}

@(export, link_name="ygg_some_str", require_results)
some_string :: proc "c" (value: cstring) -> Maybe(cstring) {
  return value;
}

@(export, link_name="ygg_is_some_c", require_results)
is_some_char :: proc "c" (opt: Maybe(i8)) -> bool {
  return is_some(opt);
}

@(export, link_name="ygg_is_some_i", require_results)
is_some_int :: proc "c" (opt: Maybe(i32)) -> bool {
  return is_some(opt);
}

@(export, link_name="ygg_is_some_f", require_results)
is_some_float :: proc "c" (opt: Maybe(f32)) -> bool {
  return is_some(opt);
}

@(export, link_name="ygg_is_some_str", require_results)
is_some_string :: proc "c" (opt: Maybe(cstring)) -> bool {
  return is_some(opt);
}

@(export, link_name="ygg_is_none", require_results)
is_none_c :: proc "c" (opt: rawptr) -> bool {
  return opt == nil;
}

@(export, link_name="ygg_unwrap", require_results)
unwrap_c :: proc "c" (opt: ^Maybe($T)) -> T {
  switch value in opt {
  case T: return value;
  case:   panic_contextless("Unwrapping a None Value");
  }

  panic_contextless("Unreachable");
}

@(export, link_prefix="ygg_", require_results)
unwrap_or_c :: proc "c" (opt: ^Maybe($T), default: T) -> T {
  switch value in opt {
  case T: return value;
  case:   return default;
  }

  panic_contextless("Unreachable");
}
