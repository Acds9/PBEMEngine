#version 460

#extension GL_GOOGLE_include_directive : require
#extension GL_EXT_buffer_reference : require
#extension GL_EXT_buffer_reference2 : require 
#extension GL_EXT_shader_explicit_arithmetic_types : require  
#extension GL_EXT_scalar_block_layout : require
#extension GL_EXT_nonuniform_qualifier : require

layout(location = 0) in vec2 frag_uv;
layout(location = 1) in vec4 frag_color;
layout(location = 0) out vec4 out_color;

layout(set = 0, binding = 0) uniform texture2D textures[];
layout(set = 1, binding = 0) uniform sampler samplers[];

layout(push_constant) uniform PushConstants {
    vec2 scale;
    vec2 translate;
    uint64_t vertex_buffer_addr;
    uint texture_index;
};

void main() {
    out_color = frag_color * texture(sampler2D(textures[texture_index], samplers[0]), frag_uv);
}