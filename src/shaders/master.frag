#version 460

#extension GL_GOOGLE_include_directive : require
#extension GL_EXT_buffer_reference : require
#extension GL_EXT_buffer_reference2 : require 
#extension GL_EXT_shader_explicit_arithmetic_types_int64 : require  
#extension GL_EXT_nonuniform_qualifier : require
#extension GL_EXT_scalar_block_layout : require

#include "input_structures.glsl"


layout(set = 0, binding = 0) uniform texture2D textures[];
layout(set = 1, binding = 0) uniform sampler samplers[];


layout(location = 0) in vec3 in_normal;
layout(location = 1) in vec2 in_UV;
layout(location = 2) in vec3 in_world_pos;
layout(location = 3) flat in uint in_material_index;

layout (location = 0) out vec4 out_color;

vec3 sunlight_direction = vec3(0.5f, 0.5f, 0.f);
vec3 ambient_color = vec3(.1f, .1f, .1f);
vec4 sunlight_color = vec4(1.f, 1.f, 1.f, 0.f);

void main() 
{
    Material_Buffer material_buffer = Material_Buffer(push_constants.material_buffer_address);
    Material_Instance mat = material_buffer.materials[in_material_index];
    
    switch(uint(mat.type))
    {
        case 0: //Opaque
        {  
            // Sample textures using indices from material
            vec3 albedo = texture(sampler2D(textures[mat.albedo_image_index], samplers[0]), in_UV).rgb;
            albedo *= mat.color_factors.rgb;  // Apply tint
            
            vec3 final_color = albedo;
            
            out_color = vec4(final_color, 1.0);
            break;
        }
    }
    
}