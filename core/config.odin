package core;

verify_config :: proc (config: map[string]string) -> (sanitized_config: map[string]string, error: Error) {
  return {}, Error.None;
}

parse_config :: proc (verified_config: map[string]string) -> (debug_level: DebugLevel, style: map[string]any, properties: map[string]any, error: Error) {
  return DebugLevel.Normal, {}, {}, Error.None;
}
