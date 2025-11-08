#version 460

#extension GL_GOOGLE_include_directive : require
#extension GL_EXT_buffer_reference : require
#extension GL_EXT_shader_explicit_arithmetic_types_int64 : require  
#extension GL_EXT_scalar_block_layout : require

#include "input_structures.glsl"
#include "debug_types.glsl"

layout(location = 0) flat in uint in_material_index;

layout (location = 0) out vec4 out_frag_color;

void main() {
    Debug_Material_Buffer material_buffer = Debug_Material_Buffer(push_constants.material_buffer_address);
     Debug_Material_Instance mat = material_buffer.materials[in_material_index];

    out_frag_color = mat.color_factors;
}