#version 450

#extension GL_GOOGLE_include_directive : require
#extension GL_EXT_buffer_reference : require
#extension GL_EXT_buffer_reference2 : require 
#extension GL_EXT_shader_explicit_arithmetic_types_int64 : require  
#extension GL_EXT_nonuniform_qualifier : require

#include "input_structures.glsl"

layout (location = 0) in vec3 in_normal;
layout (location = 1) in vec3 in_color;
layout (location = 2) in vec2 in_UV;

layout (location = 0) out vec4 out_frag_color;

vec3 sunlight_direction = vec3(0.5f, 0.5f, 0.f);
vec3 ambient_color = vec3(1.f, 1.f, 1.f);
vec4 sunlight_color = vec4(1.f, 1.f, 1.f, 1.f);

void main() 
{
	CameraData scene = CameraData(push_constants.camera_data_address);
	
	// Sample texture using bindless array
    vec3 tex_color = texture(sampler2D(images[push_constants.color_texture_index], samplers[push_constants.sampler_index]), in_UV).xyz;

	float light_value = max(dot(in_normal, sunlight_direction.xyz), 0.1f);

	vec3 color = in_color * tex_color;
    vec3 ambient = color * ambient_color.xyz;
    
    out_frag_color = vec4(color * light_value * sunlight_color.w + ambient, 1.0f);
}