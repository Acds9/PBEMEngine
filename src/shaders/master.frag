#version 460

#extension GL_GOOGLE_include_directive : require
#extension GL_EXT_buffer_reference : require
#extension GL_EXT_buffer_reference2 : require 
#extension GL_EXT_shader_explicit_arithmetic_types : require  
#extension GL_EXT_nonuniform_qualifier : require
#extension GL_EXT_scalar_block_layout : require

#include "common_types.glsl"
#include "light_types.glsl"
#ifdef DEBUG
    #include "debug.glsl"
#endif

layout(push_constant, scalar) uniform Draw_Push_Constants {
    uint64_t render_globals_address;
    uint64_t bda_draws;
    uint64_t bda_flattened_transforms;
    uint64_t bda_vertices;
    uint64_t bda_camera;
    uint64_t bda_materials;
    uint64_t bda_cluster_index;
    uint64_t bda_point_lights;
    uint point_lights_count;

    #ifdef DEBUG
        uint light_cluster_mode;
    #endif
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
    float ndc_z = window_depth;
    
    // Linearize depth to view space
    float view_z = (far * near) / (near - ndc_z * (near - far));
    return view_z;
}

float get_view_space_depth_reversed(float window_depth, float near, float far) {
    // 1.0 is near, 0.0 is far
    // Convert to linear view space distance
    return far * near / (far + window_depth * (near - far));
}

vec3 evaluate_point_light(Point_Light light, vec3 world_pos, vec3 normal) {
    vec3 light_dir = light.position - world_pos;
    float distance = length(light_dir);
    
    // Outside radius = gone
    if (distance > light.radius) return vec3(0.0);
    
    light_dir = normalize(light_dir);
    
    // Basic diffuse, replace this
    float n_dot_l = max(dot(normal, light_dir), 0.0);
    
    float attenuation = 1.0 - (distance / light.radius);
    attenuation = attenuation * attenuation; // Squared falloff
    
    return light.color.rgb * light.color.a * n_dot_l * attenuation;
}

void main() 
{
    Render_Globals globals = Render_Globals(push_constants.render_globals_address);

    Material_Buffer material_buffer = Material_Buffer(push_constants.bda_materials);
    Material_Instance mat = material_buffer.materials[in_material_index];
  
    Light_Indices_Buffer light_index_buffer = Light_Indices_Buffer(push_constants.bda_cluster_index);
    Point_Light_Data light_data_buffer = Point_Light_Data(push_constants.bda_point_lights);

    uvec3 cluster_count = uvec3(CLUSTER_X, CLUSTER_Y, CLUSTER_Z);
    vec2 screen_size = vec2(globals.resolution_x, globals.resolution_y);
    vec2 tile_size = screen_size / cluster_count.xy;

    float view_depth = get_view_space_depth(gl_FragCoord.z, Z_NEAR, Z_FAR);
    float depth_slice = log(view_depth / Z_NEAR) / log(Z_FAR / Z_NEAR) * cluster_count.z;

    uint cluster_x = min(uint(gl_FragCoord.x / tile_size.x), cluster_count.x - 1);
    uint cluster_y = min(uint(gl_FragCoord.y / tile_size.y), cluster_count.y - 1);
    uint cluster_z = uint(clamp(depth_slice, 0.0, float(cluster_count.z - 1)));
    
    uint cluster_index = cluster_z * cluster_count.x * cluster_count.y + cluster_y * cluster_count.x + cluster_x;
    uint cluster_buffer_offset = cluster_index * MAX_LIGHTS_PER_CLUSTER;
    
    uint light_count = light_index_buffer.cluster_light_indices[cluster_buffer_offset];

    #ifdef DEBUG
        if(push_constants.light_cluster_mode == 0){}
        else if(push_constants.light_cluster_mode == 1){
            out_color = vec4(vec3(float(cluster_z)/float(cluster_count.z - 1)), 1.0);
            return;
        }
        else if(push_constants.light_cluster_mode == 2){
            out_color = vec4(depth_slice_colors[cluster_z % 8], 1.0);
            return;
        }
        else if(push_constants.light_cluster_mode == 3){
            out_color = vec4(float(cluster_x)/float(cluster_count.x - 1), float(cluster_y)/float(cluster_count.y - 1), 0, 1);
            return;
        }
        else if(push_constants.light_cluster_mode == 4){
            float a = float(light_count)/float(MAX_LIGHTS_PER_CLUSTER);
            out_color = mix(vec4(0, 0.25, 0, 1), vec4(1,0,0,1), a);
            return;
        }
    #endif
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
            albedo *= mat.color_factors.rgb; 
            
            vec3 final_color = albedo * lighting;
            
            out_color = vec4(final_color, 1.0);
            break;
        }
    }
}
