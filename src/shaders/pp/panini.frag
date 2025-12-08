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

// Inverse Panini for x-coordinate, given Panini-space x, returns rectilinear x (tan of angle)
float inverse_panini_x(float px, float d) {
    // Initial guess (rectilinear)
    float u = px;
    
    // NewtonRaphson iteration
    for (int i = 0; i < 3; i++) {
        float sqrt_term = sqrt(1.0 + u * u);
        float denom = 1.0 + d * sqrt_term;
        float f = (d + 1.0) * u / denom - px;
        float df = (d + 1.0) * (sqrt_term + d) / (sqrt_term * denom * denom);
        u = u - f / df;
    }
    return u;
}

void main() {
    if (push_constants.d <= 0.0) {
        out_color = texture(sampler2D(textures[push_constants.draw_image_idx], samplers[push_constants.sampler_idx]), in_UV);
        return;
    }
    float d = push_constants.d;
    float s = push_constants.s;
    
    // Output UV to Panini
    vec2 panini = in_UV * 2.0 - 1.0;
    panini.x *= push_constants.aspect;
    
    float tan_half_fov = tan(push_constants.fov * 0.5);
    panini *= tan_half_fov;
    
    // Invert Panini to rectilinear
    float rect_x = inverse_panini_x(panini.x, d);
    
    // Vertical squeeze inverse
    float horizontal_compression = (1.0 + d) / (1.0 + d * sqrt(1.0 + rect_x * rect_x / (tan_half_fov * tan_half_fov)));
    float rect_y = panini.y * mix(1.0, horizontal_compression, s);
    
    // To UV
    vec2 sample_uv = vec2(rect_x, rect_y) / tan_half_fov;
    sample_uv.x /= push_constants.aspect;
    sample_uv = sample_uv * 0.5 + 0.5;
    
    // Sample with border check
    if (any(lessThan(sample_uv, vec2(0.0))) || any(greaterThan(sample_uv, vec2(1.0)))) {
        out_color = vec4(0.0, 0.0, 0.0, 1.0);
    } else {
        out_color = texture(sampler2D(textures[push_constants.draw_image_idx], samplers[push_constants.sampler_idx]), sample_uv);
    }
}