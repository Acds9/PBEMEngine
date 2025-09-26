#version 450

#extension GL_GOOGLE_include_directive : require
#extension GL_EXT_buffer_reference : require
#extension GL_EXT_buffer_reference2 : require 
#extension GL_EXT_shader_explicit_arithmetic_types_int64 : require  

#include "input_structures.glsl"

layout (location = 0) out vec3 out_normal;
layout (location = 1) out vec3 out_color;
layout (location = 2) out vec2 out_UV;

struct Vertex {

	vec3 position;
	float uv_x;
	vec3 normal;
	float uv_y;
	vec4 color;
}; 

layout(buffer_reference, std430) readonly buffer VertexBuffer { 
    Vertex vertices[];
};

layout(buffer_reference, std430) readonly buffer TransformBuffer {
    mat4 transform;
};

// Push constants block
layout(push_constant) uniform constants {
    uint64_t transform_address;    // VkDeviceAddress to transform
    uint64_t vertex_buffer;        // VkDeviceAddress to vertex buffer
} push_constants;

void main() {
    // Dereference the transform address
    TransformBuffer transform_ref = TransformBuffer(push_constants.transform_address);
    mat4 world_matrix = transform_ref.transform;
    
    // Get vertex data
    VertexBuffer vertex_buffer = VertexBuffer(push_constants.vertex_buffer);
    Vertex v = vertex_buffer.vertices[gl_VertexIndex];
    
    vec4 position = vec4(v.position, 1.0);
    
    // Transform to clip space
    gl_Position = scene_data.view_proj * world_matrix * position;
    
    // Transform normal to world space
    out_normal = (world_matrix * vec4(v.normal, 0.0)).xyz;
    out_color = v.color.xyz * material_data.color_factors.xyz;
    out_UV.x = v.uv_x;
    out_UV.y = v.uv_y;
}