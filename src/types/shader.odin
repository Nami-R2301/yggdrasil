package types;

ShaderType :: enum u8 {
    Vertex = 0,
    Fragment,
    Geometry,
    Compute
}

ShaderError :: enum u8 {
    None = 0,
    InvalidFile,
    UnsupportedType,
    APIError,
    ProgramError
}