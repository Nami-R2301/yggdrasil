package examples

config :: proc () {
    // Manual configs.
    temp_config : map[string]string = { };

    temp_config["log_level"] = "vvv";      // Log Verbosity. Defaults to normal or 'v'.
    temp_config["log_file"] = "logs.txt"; // Where do we log the app's logs.
    temp_config["headless"] = "";         // If we plan on using a window. Defaults to a falsy value.
    temp_config["optimization"] = "speed";    // Optimization level. This will disable stdout logging and batch renderer commands if supported for speed. Defaults to debug.
    temp_config["cache"] = "";         // If we want to enable caching of nodes. Defaults to a truthy value.
    temp_config["renderer"] = "";         // If we plan on rendering nodes. Defaults to a truthy value.

    // TODO: Read from config.toml and potentially import HTML and CSS as well.
    return;
}