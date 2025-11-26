#version 460

#extension GL_GOOGLE_include_directive : require
#extension GL_EXT_buffer_reference : require
#extension GL_EXT_buffer_reference2 : require 
#extension GL_EXT_shader_explicit_arithmetic_types : require  
#extension GL_EXT_scalar_block_layout : require

#include "common_types.glsl"

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
} push_constants;

layout (location = 0) out vec3 out_normal;
layout (location = 1) out vec2 out_UV;
layout (location = 2) out vec3 out_world_pos;
layout (location = 3) flat out uint out_material_index;

void main() {
    Draw_Command_Buffer draw_buffer = Draw_Command_Buffer(push_constants.bda_draws);
    Draw_Command draw = draw_buffer.commands[gl_DrawID];

    Vertex_Buffer vertex_buffer = Vertex_Buffer(push_constants.bda_vertices);
    Vertex v = vertex_buffer.vertices[gl_VertexIndex];

    Flattened_Transform_Buffer transform_buffer = Flattened_Transform_Buffer(push_constants.bda_transforms);
    mat4 world_matrix = transform_buffer.transforms[draw.idx_transform];

    Camera_Data camera = Camera_Data(push_constants.bda_camera);

    vec4 position = vec4(v.position, 1.0);
    vec4 world_pos = world_matrix * position;
   
    // Transform to clip space
    gl_Position = camera.view_proj * world_matrix * position;
    
    // Transform normal to world space
    out_normal = (world_matrix * vec4(v.normal, 0.0)).xyz;
    out_UV.x = v.uv_x;
    out_UV.y = v.uv_y;
    out_world_pos = world_pos.xyz;
    out_material_index = draw.idx_material_instance;
}