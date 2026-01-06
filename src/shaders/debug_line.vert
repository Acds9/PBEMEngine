#version 460

#extension GL_GOOGLE_include_directive : require
#extension GL_EXT_buffer_reference : require
#extension GL_EXT_buffer_reference2 : require 
#extension GL_EXT_shader_explicit_arithmetic_types_int64 : require  
#extension GL_EXT_scalar_block_layout : require

#include "debug_types.glsl"


layout(buffer_reference, scalar) readonly buffer Camera_Data {
	mat4 view;
	mat4 proj;
	mat4 view_proj;
};

layout(push_constant, scalar) uniform Debug_Line_Push_Constants {
    uint64_t render_globals_address;
    uint64_t bda_vertex;
    uint64_t bda_camera;
} debug_push_constants;

layout(location = 0) out vec3 outColor;

void main() {
    const uint stride = 32; 
    uint64_t line_offset = debug_push_constants.bda_vertex + (gl_VertexIndex * stride);
    
    Line_Data p = Line_Data(line_offset);
    Camera_Data camera = Camera_Data(debug_push_constants.bda_camera);
    
    gl_Position = camera.view_proj * vec4(p.position, 1.0);
    outColor = p.color.xyz;
}