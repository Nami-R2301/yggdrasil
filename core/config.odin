package core;

verify_config :: proc (config: map[string]string) -> (sanitized_config: map[string]string, error: FileError) {
  return {}, FileError.None;
}

parse_config :: proc (verified_config: map[string]string) -> (debug_level: DebugLevel, style: map[string]any, properties: map[string]any, nodes: [dynamic]Node, error: FileError) {
  return DebugLevel.Normal, {}, {}, {}, FileError.None;
}
