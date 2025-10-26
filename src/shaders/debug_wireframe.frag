#version 450

#extension GL_GOOGLE_include_directive : require
#extension GL_EXT_buffer_reference : require
#extension GL_EXT_shader_explicit_arithmetic_types_int64 : require  
#extension GL_EXT_scalar_block_layout : require

#include "input_structures.glsl"

layout (location = 0) out vec4 out_frag_color;
vec4 color = vec4(1.f, 1.f, 1.f, 1.f);

void main() {
    MaterialData mat = MaterialData(push_constants.material_address);
    out_frag_color = mat.color_factors;
}