package ygg;

import types "types";
import utils "utils"

// Core API to sanitize a config file and auto-generate default values for any option missing or set
// to none.
//
// @param   *config*: An optional map of features that will configure the current context. Keys with none values
//                    will revert to defaults. Will read the config.toml file at the root if no explicit
//                    config is provided.
// @param   *indent*: The depth of the indent for all logs within this function.
// @return  A sanitized version of the config provided as input.
sanitize_config :: proc (config_opt: types.Option(map[string]types.Option(string)) = nil, indent: string = "  ") -> types.Result(map[string]string) {
    new_config := utils.default_config();
    config_read: map[string]types.Option(string) = {};
    if !utils.is_some(config_opt) {
        // Attempt to read from toml file.
        result_config := read_config();
        if result_config.error != types.ConfigError.None {
            return { error = result_config.error, opt = utils.none(map[string]string) };
        }
        config_read = utils.unwrap(result_config.opt);
    }

    for key, value_opt in config_read {
        if utils.is_some(value_opt) {
            value := utils.unwrap(value_opt);
            switch key {
                case "log_level":   new_config[key] = utils.into_str(utils.into_debug(value));
                case "log_file":
                    switch value {
                        case "":    new_config[key] = "n/a";
                        case:       new_config[key] = value;
                    }
                case "optimization": {
                    switch value {
                        case "speed":   new_config[key] = "speed";
                        case "memory":  new_config[key] = "memory";
                        case:           new_config[key] = "debug";
                    }
                }
                case "renderer": {
                    switch value {
                        case "Vulkan":  new_config[key] = "Vulkan";
                        case:           new_config[key] = "OpenGL";
                    }
                }
                case "cache": {
                    new_config[key] = utils.into_str(utils.into_bool(value));
                }
                case "headless":
                    new_config[key] = utils.into_str(utils.into_bool(value));
                }
        }
    }
    return { error = types.ConfigError.None, opt = utils.some(new_config) };
}

// Core API to attempt to read the yggdrasil config toml file and return its options with a key-value
// map, where any features missing in the file, will result in none. When parsed, they will default to
// their respective default values.
//
// @param   *indent*:   The depth of the indent for all logs within this function.
// @return  An error if one occurred and an optional map of key-value pairs corresponding to features
//          and options available for configuring the context if no errors occurred.
// TODO: Read from file.
read_config :: proc (indent: string = "  ") ->  types.Result(map[string]types.Option(string)) {
    panic("Unimplemented");
}
