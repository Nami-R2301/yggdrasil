package ygg;

import gl "vendor:OpenGL";

import types "types";

@(export, link_prefix="ygg_", require_results)
load_shaders :: proc (filepaths: []string = {}) -> (u32, types.ShaderError) {
    program_id, is_ok := gl.load_shaders(filepaths[0], filepaths[1]);
    if !is_ok {
        return program_id, types.ShaderError.ProgramError;
    }

    return program_id, types.ShaderError.None;
}

@(export, link_prefix="ygg_", require_results)
get_last_program :: proc "c" () -> (u32, bool) {
    program_id: i32 = 0;

    gl.GetIntegerv(gl.CURRENT_PROGRAM, &program_id);
    if program_id <= 0 {
        return 0, false;
    }

    return u32(program_id), true;
}