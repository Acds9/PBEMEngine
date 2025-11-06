#version 460

#extension GL_GOOGLE_include_directive : require
#extension GL_EXT_buffer_reference : require
#extension GL_EXT_buffer_reference2 : require 
#extension GL_EXT_scalar_block_layout : require

#include "input_structures.glsl"

layout (location = 0) out vec3 out_normal;
layout (location = 1) out vec2 out_UV;
layout (location = 2) out vec3 out_world_pos;
layout (location = 3) flat out uint out_material_index;

struct Vertex {
	vec3 position;
	float uv_x;
	vec3 normal;
	float uv_y;
	vec4 color;
}; 
layout(buffer_reference, scalar) readonly buffer Vertex_Buffer { 
    Vertex vertices[];
};

struct Indexed_Indirect_Cmd {
    uint index_count;
    uint instance_count;
    uint first_index;
    int vertex_offset;
    uint first_instance; 
};
struct Draw_Command {
    Indexed_Indirect_Cmd draw_cmd;
    uint64_t vertex_address;
    uint64_t transform_address;
    uint material_instance;
    uint8_t padding[4];
};
layout(buffer_reference, scalar) readonly buffer Indexed_Indirect_Buffer { 
    Draw_Command commands[];
};

struct Transform {
    mat4 transform;
    uint64_t parent_address;
    uint8_t padding[8];
};
layout(buffer_reference, scalar) readonly buffer Transform_Buffer {
    Transform transform;
};

void main() {
    Indexed_Indirect_Buffer draw_buffer = Indexed_Indirect_Buffer(push_constants.draw_buffer_address);
    Draw_Command draw = draw_buffer.commands[gl_DrawID];

    Vertex_Buffer vertex_buffer = Vertex_Buffer(draw.vertex_address);
    Vertex v = vertex_buffer.vertices[gl_VertexIndex];

    Transform_Buffer transform_buffer = Transform_Buffer(draw.transform_address);
    Transform transform = transform_buffer.transform;
    mat4 world_matrix = transform.transform; // Need to actually calc this one from parents

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