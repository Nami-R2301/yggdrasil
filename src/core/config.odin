package core;

verify_config :: proc (config: map[string]Option(string)) -> (Error, map[string]Option(string)) {
  return Error.None, config;
}

parse_config :: proc (verified_config: map[string]Option(string)) -> (error: Error, debug_level: DebugLevel) {
  for key, &value in verified_config {
    if key == "debug_level" {
      switch unwrap_or(value, "None") {
        case "None":        debug_level = DebugLevel.None;
        case "Normal":      debug_level = DebugLevel.Normal;
        case "Verbose":     debug_level = DebugLevel.Verbose;
        case "Everything":  debug_level = DebugLevel.Everything;
        case:               debug_level = DebugLevel.None;
      }
    }
  }

  return Error.None, debug_level;
}
