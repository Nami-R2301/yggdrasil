package yggdrasil;

import "core:strconv";
import "core:fmt";
import "core:mem";

import types "types";
import utils "utils";

verify_config :: proc (config: map[string]types.Option(string)) -> (types.ContextError, map[string]types.Option(string)) {
  return types.ContextError.None, config;
}

parse_config :: proc (verified_config: map[string]types.Option(string)) -> (types.ContextError, map[string]string) {
  parsed_config: map[string]string = {};
  // Set default configs.
  parsed_config = utils.default(parsed_config);

  for key, value_opt in verified_config {
    if utils.is_some(value_opt) {

      value := utils.unwrap(value_opt);
      switch key {
        case "log_level":       parsed_config[key] = utils.into_str(utils.into_debug(value));
        case "optimization": {
          switch value {
            case "release":     parsed_config[key] = "release";
            case "test":        parsed_config[key] = "test";
            case:               parsed_config[key] = "debug";
          }
        }
        case "renderer": {
          switch value {
            case "OpenGL":      parsed_config["renderer"] = "OpenGL";
            case:               parsed_config["renderer"] = "Vulkan";
          }
        }
        case "headless": 
          parsed_config[key] = utils.into_str(utils.into_bool(value));
      }
    }
  }

  return types.ContextError.None, parsed_config;
}
