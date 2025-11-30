#version 420 core

// Vertex attributes.
layout (location = 0) in int  vin_entity_ID;
layout (location = 1) in vec3 vin_position;
layout (location = 2) in vec4 vin_color;
layout (location = 3) in vec2 vin_tex_coords;

// View matrix.
uniform mat4 u_view = mat4(1.0f);

// Input variables.
uniform vec3 u_mouse_pos = vec3(0.0f);

// Outputs.
struct Vertex_data_s
{
    vec2 vout_tex_coords;
    vec4 vout_frag_color;
    vec3 vout_frag_position;
};

layout (location = 0) flat  out int vout_entity_ID;
layout (location = 1)       out Vertex_data_s vout_vertex_data;

void main()
{
    gl_Position = u_view * vec4(vin_position.xyz, 1.0);

    vout_vertex_data.vout_tex_coords    = vin_tex_coords;
    vout_vertex_data.vout_frag_color    = vin_color;
    vout_vertex_data.vout_frag_position = vin_position;
    vout_entity_ID                      = vin_entity_ID;
}