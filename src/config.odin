package yggdrasil;

import types "types";
import utils "utils";

verify_config :: proc (config: map[string]types.Option(string)) -> (types.ContextError, map[string]types.Option(string)) {
  return types.ContextError.None, config;
}

parse_config :: proc (verified_config: map[string]types.Option(string)) -> (error: types.ContextError, debug_level: types.DebugLevel, target: string) {
  for key, &value in verified_config {
    if key == "debug_level" {
      switch utils.unwrap_or(value, "None") {
        case "None":        debug_level = types.DebugLevel.None;
        case "Normal":      debug_level = types.DebugLevel.Normal;
        case "Verbose":     debug_level = types.DebugLevel.Verbose;
        case "Everything":  debug_level = types.DebugLevel.Everything;
        case:               debug_level = types.DebugLevel.None;
      }
    }
    if key == "target" {
      target = utils.unwrap_or(value, "debug"); 
    }
  }

  return types.ContextError.None, debug_level, target;
}
