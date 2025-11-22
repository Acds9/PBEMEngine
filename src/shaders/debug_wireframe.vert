#version 460

#extension GL_GOOGLE_include_directive : require
#extension GL_EXT_buffer_reference : require
#extension GL_EXT_buffer_reference2 : require
#extension GL_EXT_shader_explicit_arithmetic_types : require  
#extension GL_EXT_scalar_block_layout : require
#include "common_types.glsl"
#include "debug_types.glsl"

layout(push_constant, scalar) uniform Debug_Wireframe_Push_Constants {
    uint64_t render_globals_address;
    uint64_t draw_buffer_address;
    uint64_t camera_data_address;
    uint64_t material_buffer_address;
} push_constants;

layout (location = 0) flat out uint out_material_index;

void main() {
    Indexed_Indirect_Buffer draw_buffer = Indexed_Indirect_Buffer(push_constants.draw_buffer_address);
    Draw_Command draw = draw_buffer.commands[gl_DrawID];

    Vertex_Buffer vertex_buffer = Vertex_Buffer(draw.vertex_address);
    Vertex v = vertex_buffer.vertices[gl_VertexIndex];

    Transform_Buffer transform_buffer = Transform_Buffer(draw.transform_address);
    Transform transform = transform_buffer.transforms[0];
    mat4 world_matrix = transform.transform; // Need to actually calc this one from parents, do it in CPU side

    Camera_Data camera = Camera_Data(push_constants.camera_data_address);

    vec4 position = vec4(v.position, 1.0);
    vec4 world_pos = world_matrix * position;

    out_material_index = draw.material_instance;
    gl_Position = camera.view_proj * world_matrix * vec4(v.position, 1.0);
}