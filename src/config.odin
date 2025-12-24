package ygg;

import fmt      "core:fmt";
import os       "core:os";
import ttf      "vendor:stb/truetype";
import runtime  "base:runtime";

import types "types";
import utils "utils";

// Core API to sanitize a config file and auto-generate default values for any option missing or set
// to none.
//
// @param   *config*: An optional map of features that will configure the current context. Keys with none values
//                    will revert to defaults. Will read the config.toml file at the root if no explicit
//                    config is provided.
// @param   *indent*: The depth of the indent for all logs within this function.
// @return  A sanitized version of the config provided as input.
sanitize_config :: proc (config_opt: types.Option(map[string]types.Option(string)) = nil, indent: string = "  ") -> (map[string]string, types.Error) {
    using types;
    using utils;

    new_config := default_config();
    config_read: map[string]Option(string) = {};
    if !is_some(config_opt) {
        // Attempt to read from toml file.
        config_read, error := read_config();
        if error != ConfigError.None {
            return {}, error;
        }
    }

    for key, value_opt in config_read {
        if is_some(value_opt) {
            value := unwrap(value_opt);
            switch key {
                case "log_level":   new_config[key] = into_str(into_debug(value));
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
                    new_config[key] = into_str(into_bool(value));
                }
                case "headless":
                    new_config[key] = into_str(into_bool(value));
                }
        }
    }
    return new_config, ConfigError.None;
}

// Core API to attempt to read the yggdrasil config toml file and return its options with a key-value
// map, where any features missing in the file, will result in none. When parsed, they will default to
// their respective default values.
//
// @param   *indent*:   The depth of the indent for all logs within this function.
// @return  An error if one occurred and an optional map of key-value pairs corresponding to features
//          and options available for configuring the context if no errors occurred.
// TODO: Read from file.
read_config :: proc (indent: string = "  ") ->  (map[string]types.Option(string), types.Error) {
    panic("Unimplemented");
}

// Returns the width and height of the string in pixels
measure_string :: proc(info: ^ttf.fontinfo, text: string, font_size: f32) -> (width: f32, height: f32) {
    // 1. Calculate the scale factor for the desired pixel height
    scale := ttf.ScaleForPixelHeight(info, font_size)

    // 2. Calculate Height (Ascent - Descent)
    ascent, descent, line_gap: i32
    ttf.GetFontVMetrics(info, &ascent, &descent, &line_gap)
    height = f32(ascent - descent) * scale

    // 3. Calculate Width (Sum of advances + kerning)
    width = 0
    last_codepoint: rune = -1

    for r in text {
        advance, lsb: i32
        ttf.GetCodepointHMetrics(info, r, &advance, &lsb)

        // Add kerning (adjustment between specific pairs, e.g., 'A' and 'V')
        if last_codepoint != -1 {
            kern := ttf.GetCodepointKernAdvance(info, last_codepoint, r)
            width += f32(kern) * scale
        }

        width += f32(advance) * scale
        last_codepoint = r
    }

    return
}
