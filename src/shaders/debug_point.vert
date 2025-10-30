#version 460

#extension GL_GOOGLE_include_directive : require
#extension GL_EXT_buffer_reference : require
#extension GL_EXT_buffer_reference2 : require 
#extension GL_EXT_shader_explicit_arithmetic_types_int64 : require  
#extension GL_EXT_scalar_block_layout : require

layout(push_constant) uniform PushConstants {
    uint64_t point_address;
	uint64_t transform_address;
	uint64_t camera_data_address;
} push_constants;

layout(buffer_reference, scalar) readonly buffer PointData { 
    vec3 position;
	float size;
	vec4 color;
};

layout(buffer_reference, scalar) readonly buffer CameraData {
	mat4 view;
	mat4 proj;
	mat4 view_proj;
};

layout(location = 0) out vec3 outColor;

void main() {
    // Calculate offset for this vertex
    const uint stride = 32; // sizeof(Debug_Point)
    uint64_t point_offset = push_constants.point_address + (gl_VertexIndex * stride);
    
    PointData p = PointData(point_offset);
    CameraData camera = CameraData(push_constants.camera_data_address);
    
    gl_Position = camera.view_proj * vec4(p.position, 1.0);
    gl_PointSize = p.size;
    outColor = p.color.xyz;
}