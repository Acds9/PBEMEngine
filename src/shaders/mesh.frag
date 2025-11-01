#version 450

#extension GL_GOOGLE_include_directive : require
#extension GL_EXT_buffer_reference : require
#extension GL_EXT_buffer_reference2 : require 
#extension GL_EXT_shader_explicit_arithmetic_types_int64 : require  
#extension GL_EXT_nonuniform_qualifier : require
#extension GL_EXT_scalar_block_layout : require

#include "input_structures.glsl"

layout (location = 0) in vec3 in_normal;
layout (location = 1) in vec3 in_color;
layout (location = 2) in vec2 in_UV;
layout (location = 3) in vec3 in_world_pos;

layout (location = 0) out vec4 out_frag_color;

vec3 sunlight_direction = vec3(0.5f, 0.5f, 0.f);
vec3 ambient_color = vec3(.1f, .1f, .1f);
vec4 sunlight_color = vec4(1.f, 1.f, 1.f, 0.f);

void main() 
{
    CameraData scene = CameraData(push_constants.camera_data_address);
    MaterialData mat = MaterialData(push_constants.material_address);
    Point_Light_Data point_lights = Point_Light_Data(push_constants.point_lights_address);
    
    vec3 tex_color = texture(sampler2D(images[mat.albedo_image_index], samplers[mat.albedo_sampler_index]), in_UV).xyz;

    vec3 ambient = tex_color * ambient_color.xyz; 
    
    // Directional sunlight (your existing code)
    float sun_diffuse = max(dot(in_normal, normalize(sunlight_direction)), 0.0)*0; // Sunlight off for now
    vec3 lighting = sunlight_color.xyz * sun_diffuse;
    
    // Add point lights
    for (uint i = 0; i < push_constants.point_lights_count; i++) {
        PointLight light = point_lights.lights[i];
        
        // Vector from fragment to light
        vec3 light_dir = light.position - in_world_pos; // Need world position here, see below
        float distance = length(light_dir);
        light_dir = normalize(light_dir);
        
        // Simple attenuation: light fades to zero at radius
        float attenuation = max(0.0, 1.0 - (distance / light.radius));
        attenuation = attenuation * attenuation; // Squared falloff looks better
        
        // Diffuse lighting
        float diffuse = max(dot(in_normal, light_dir), 0.0);
        
        // Accumulate
        lighting += light.color.xyz * diffuse * attenuation;
    }
    
    out_frag_color = vec4(tex_color * lighting + ambient, 1.0);
}