#version 420 core

struct Vertex_data_s
{
    vec2 vout_tex_coords;     // Texture coordinates.
    vec4 vout_frag_color;     // Base material color.
    vec3 vout_frag_position;  // Start of fragment position.
};

layout (location = 0) flat  in int vout_entity_ID;
layout (location = 1)       in Vertex_data_s vout_vertex_data;

layout (location = 0) out vec4 fout_frag_color;
layout (location = 1) out int  fout_entity_ID;

// Texture.
layout (binding = 10) uniform sampler2D u_sampler;
uniform bool u_has_texture = false;

void main()
{
    vec4 color = vec4(1.0f);
    if (!u_has_texture) color *= vout_vertex_data.vout_frag_color;
    else color = texture(u_sampler, vout_vertex_data.vout_tex_coords);

    fout_frag_color = color;
    fout_entity_ID  = vout_entity_ID;
}