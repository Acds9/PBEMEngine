#version 460

#extension GL_GOOGLE_include_directive : require
#extension GL_EXT_buffer_reference : require
#extension GL_EXT_buffer_reference2 : require 
#extension GL_EXT_scalar_block_layout : require

#include "common_types.glsl"

layout(push_constant, scalar) uniform Draw_Push_Constants {
    uint64_t render_globals_address;
    uint64_t draw_buffer_address;
    uint64_t camera_data_address;
    uint64_t material_buffer_address;
    uint64_t light_cluster_buffer_address;
    uint64_t point_lights_address;
    uint point_lights_count;
} push_constants;

layout (location = 0) out vec3 out_normal;
layout (location = 1) out vec2 out_UV;
layout (location = 2) out vec3 out_world_pos;
layout (location = 3) flat out uint out_material_index;

void main() {
    Indexed_Indirect_Buffer draw_buffer = Indexed_Indirect_Buffer(push_constants.draw_buffer_address);
    Draw_Command draw = draw_buffer.commands[gl_DrawID];

    Vertex_Buffer vertex_buffer = Vertex_Buffer(draw.vertex_address);
    Vertex v = vertex_buffer.vertices[gl_VertexIndex];

    Transform_Buffer transform_buffer = Transform_Buffer(draw.transform_address);
    Transform transform = transform_buffer.transform;
    mat4 world_matrix = transform.transform; // Need to actually calc this one from parents, do it in CPU side

    Camera_Data camera = Camera_Data(push_constants.camera_data_address);

    vec4 position = vec4(v.position, 1.0);
    vec4 world_pos = world_matrix * position;
   
    // Transform to clip space
    gl_Position = camera.view_proj * world_matrix * position;
    
    // Transform normal to world space
    out_normal = (world_matrix * vec4(v.normal, 0.0)).xyz;
    out_UV.x = v.uv_x;
    out_UV.y = v.uv_y;
    out_world_pos = world_pos.xyz;
    out_material_index = draw.material_instance;
}