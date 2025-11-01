#version 450

#extension GL_GOOGLE_include_directive : require
#extension GL_EXT_buffer_reference : require
#extension GL_EXT_buffer_reference2 : require
#extension GL_EXT_scalar_block_layout : require
#include "input_structures.glsl"

struct Vertex {
    vec3 position;
    float uv_x;
    vec3 normal;
    float uv_y;
    vec4 color;
}; 

layout(buffer_reference, scalar) readonly buffer VertexBuffer { 
    Vertex vertices[];
};

layout(buffer_reference, scalar) readonly buffer TransformBuffer {
    Transform transforms[];
};

void main() {
    CameraData camera = CameraData(push_constants.camera_data_address);
    TransformBuffer transform_ref = TransformBuffer(push_constants.transform_address);
    VertexBuffer vertex_buffer = VertexBuffer(push_constants.vertex_address);
    
    Vertex v = vertex_buffer.vertices[gl_VertexIndex];
    gl_Position = camera.view_proj * transform_ref.transforms[0].transform * vec4(v.position, 1.0);
}