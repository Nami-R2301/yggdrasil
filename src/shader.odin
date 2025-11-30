package ygg;

import gl "vendor:OpenGL";

import types "types";
import utils "utils";

load_shaders :: proc (filepaths: []string = {}) -> (u32, types.ShaderError) {
    using types;

    program_id, is_ok := gl.load_shaders(filepaths[0], filepaths[1]);
    if !is_ok {
        return program_id, ShaderError.ProgramError;
    }

    return program_id, ShaderError.None;
}

get_last_program :: proc () -> types.Result(u32) {
    program_id: i32 = 0;

    gl.GetIntegerv(gl.CURRENT_PROGRAM, &program_id);
    if program_id <= 0 {
        return { error = types.ProgramError.ProgramNotFound, opt = utils.none(u32) };
    }

    return { error = types.ProgramError.None, opt = utils.some(u32(program_id)) };
}