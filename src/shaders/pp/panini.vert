#version 460

#extension GL_GOOGLE_include_directive : require
#extension GL_EXT_buffer_reference : require
#extension GL_EXT_buffer_reference2 : require 
#extension GL_EXT_shader_explicit_arithmetic_types : require  
#extension GL_EXT_scalar_block_layout : require

#include "../common_types.glsl"

layout(push_constant, scalar) uniform Panini_Push_Constants {
    float fov;
    float d;
    float s;
    float aspect;
    uint draw_image_idx;
    uint sampler_idx;
} push_constants;

layout (location = 0) out vec2 out_UV;

void main() {
    vec2 uv = vec2((gl_VertexIndex << 1) & 2, gl_VertexIndex & 2);
    gl_Position = vec4(uv * 2.0 - 1.0, 0.0, 1.0);
    out_UV = uv;
}