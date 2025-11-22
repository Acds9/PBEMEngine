#version 460

#extension GL_GOOGLE_include_directive : require
#extension GL_EXT_buffer_reference : require
#extension GL_EXT_buffer_reference2 : require 
#extension GL_EXT_shader_explicit_arithmetic_types : require  
#extension GL_EXT_nonuniform_qualifier : require
#extension GL_EXT_scalar_block_layout : require

#include "common_types.glsl"
#include "light_types.glsl"

layout(push_constant, scalar) uniform Draw_Push_Constants {
    uint64_t render_globals_address;
    uint64_t draw_buffer_address;
    uint64_t camera_data_address;
    uint64_t material_buffer_address;
    uint64_t light_cluster_buffer_address;
    uint64_t point_lights_address;
    uint point_lights_count;
} push_constants;

layout(set = 0, binding = 0) uniform texture2D textures[];
layout(set = 1, binding = 0) uniform sampler samplers[];

layout(constant_id = 0) const uint CLUSTER_X = 32;
layout(constant_id = 1) const uint CLUSTER_Y = 16;
layout(constant_id = 2) const uint CLUSTER_Z = 24;
layout(constant_id = 3) const uint MAX_LIGHTS_PER_CLUSTER = 32;
layout(constant_id = 4) const float Z_NEAR = 0.1;
layout(constant_id = 5) const float Z_FAR = 10000.0;

layout(location = 0) in vec3 in_normal;
layout(location = 1) in vec2 in_UV;
layout(location = 2) in vec3 in_world_pos;
layout(location = 3) flat in uint in_material_index;

layout (location = 0) out vec4 out_color;

vec3 sunlight_direction = vec3(0.5f, 0.5f, 0.f);
vec3 ambient_color = vec3(.1f, .1f, .1f);
vec4 sunlight_color = vec4(1.f, 1.f, 1.f, 0.f);

float get_view_space_depth(float window_depth, float near, float far) {
    // Vulkan NDC Z is [0,1], gl_FragCoord.z is already in window space [0,1]
    float ndc_z = window_depth;
    
    // Linearize depth to view space (negative Z forward)
    float view_z = (far * near) / (near - ndc_z * (near - far));
    return view_z; // Return positive distance
}

float get_view_space_depth_reversed(float window_depth, float near, float far) {
    // window_depth is [0,1] where 1.0 is near, 0.0 is far
    // Convert to linear view space distance
    return far * near / (far + window_depth * (near - far));
}

vec3 evaluate_point_light(Point_Light light, vec3 world_pos, vec3 normal) {
    vec3 light_dir = light.position - world_pos;
    float distance = length(light_dir);
    
    // Outside radius? No contribution
    if (distance > light.radius) return vec3(0.0);
    
    light_dir = normalize(light_dir);
    
    // Basic diffuse (N dot L)
    float n_dot_l = max(dot(normal, light_dir), 0.0);
    
    // Distance attenuation (inverse square with smooth falloff at radius)
    float attenuation = 1.0 - (distance / light.radius);
    attenuation = attenuation * attenuation; // Squared falloff
    
    return light.color.rgb * light.color.a * n_dot_l * attenuation;
}

void main() 
{
    Render_Globals globals = Render_Globals(push_constants.render_globals_address);

    Material_Buffer material_buffer = Material_Buffer(push_constants.material_buffer_address);
    Material_Instance mat = material_buffer.materials[in_material_index];
  
    Light_Indices_Buffer light_index_buffer = Light_Indices_Buffer(push_constants.light_cluster_buffer_address);
    Point_Light_Data light_data_buffer = Point_Light_Data(push_constants.point_lights_address);

    // Clean this up, this is awful
    uvec3 cluster_count = uvec3(CLUSTER_X, CLUSTER_Y, CLUSTER_Z);
    vec2 screen_size = vec2(globals.resolution_x, globals.resolution_y);
    vec2 tile_size = screen_size / cluster_count.xy;

    float view_depth = get_view_space_depth(gl_FragCoord.z, Z_NEAR, Z_FAR);
    float depth_slice = log(view_depth / Z_NEAR) / log(Z_FAR / Z_NEAR) * cluster_count.z;

    uint cluster_x = min(uint(gl_FragCoord.x / tile_size.x), cluster_count.x - 1);
    uint cluster_y = min(uint(gl_FragCoord.y / tile_size.y), cluster_count.y - 1);
    uint cluster_z = uint(depth_slice);
    uint cluster_index = cluster_z * cluster_count.x * cluster_count.y + cluster_y * cluster_count.x + cluster_x;
    uint cluster_buffer_offset = cluster_index * MAX_LIGHTS_PER_CLUSTER;
    
    uint light_count = light_index_buffer.cluster_light_indices[cluster_buffer_offset];

    switch(uint(mat.type))
    {
        case 0: //Opaque
        {
            vec3 lighting = vec3(0.0);
            for (uint i = 1; i <= light_count; i++) {
                uint light_idx = light_index_buffer.cluster_light_indices[cluster_buffer_offset + i];
                Point_Light point_light = light_data_buffer.lights[light_idx];
                lighting += evaluate_point_light(point_light, in_world_pos, normalize(in_normal));
            }

            // Sample textures using indices from material
            vec3 albedo = texture(sampler2D(textures[mat.albedo_image_index], samplers[0]), in_UV).rgb;
            albedo *= mat.color_factors.rgb;  // Apply tint
            
            vec3 final_color = albedo * lighting;
            
            out_color = vec4(final_color, 1.0);
            break;
        }
    }
}
