#version 460

#extension GL_GOOGLE_include_directive : require
#extension GL_EXT_buffer_reference : require
#extension GL_EXT_buffer_reference2 : require 
#extension GL_EXT_shader_explicit_arithmetic_types : require  
#extension GL_EXT_scalar_block_layout : require
#extension GL_EXT_nonuniform_qualifier : require

#include "../common_types.glsl"

layout(set = 0, binding = 0) uniform texture2D textures[];
layout(set = 1, binding = 0) uniform sampler samplers[];

layout(push_constant, scalar) uniform Panini_Push_Constants {
    float fov;
    float d;
    float s;
    float aspect;
    uint draw_image_idx;
    uint sampler_idx;
} push_constants;

layout(location = 0) in vec2 in_UV;

layout (location = 0) out vec4 out_color;

void main() {
  
    float d = push_constants.d;
    float s = push_constants.s;

    // Convert UV to normalized device coords [-1, 1]
    vec2 ndc = in_UV * 2.0 - 1.0;
    
    // Aspect ratio correction
    float aspect = push_constants.aspect;
    ndc.x *= aspect;
    
    // Convert to view direction (rectilinear)
    float tan_half_fov = tan(push_constants.fov * 0.5);
    vec3 view_dir = normalize(vec3(ndc * tan_half_fov, 1.0));
    
    // Panini projection math
    float x = view_dir.x;
    float y = view_dir.y;
    float z = view_dir.z;
    
    float d_plus_1 = d + 1.0;
    float denom = z + d;
    
    vec2 panini;
    panini.x = (d_plus_1 * x) / denom;
    panini.y = (d_plus_1 * y) / (denom * mix(1.0, denom / d_plus_1, s));
    
    // Back to UV space
    vec2 sample_uv = (panini / tan_half_fov);
    sample_uv.x /= aspect;
    sample_uv = sample_uv * 0.5 + 0.5;
    
    // Sample with border check
    if (any(lessThan(sample_uv, vec2(0.0))) || any(greaterThan(sample_uv, vec2(1.0)))) {
        out_color = vec4(0.0, 0.0, 0.0, 1.0);
    } else {
        vec4 color = texture(sampler2D(textures[push_constants.draw_image_idx], samplers[push_constants.sampler_idx]), sample_uv);
        out_color = color;
    }
}