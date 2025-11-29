#version 460

#extension GL_GOOGLE_include_directive : require
#extension GL_EXT_buffer_reference : require
#extension GL_EXT_buffer_reference2 : require
#extension GL_EXT_shader_explicit_arithmetic_types : require  
#extension GL_EXT_scalar_block_layout : require
#include "common_types.glsl"
#include "debug_types.glsl"

layout(push_constant, scalar) uniform Debug_Mesh_Push_Constants {
    uint64_t render_globals;
    uint64_t bda_draw;
    uint64_t bda_vertex;
    uint64_t bda_transform;
    uint64_t bda_material;
    uint64_t bda_camera;
} push_constants;

layout (location = 0) flat out uint out_material_index;

layout(buffer_reference, scalar) buffer Debug_Draw_Command_Buffer {
    Draw_Command commands[];
};

void main() {
    Debug_Draw_Command_Buffer draw_buffer = Debug_Draw_Command_Buffer(push_constants.bda_draw);
    Draw_Command draw = draw_buffer.commands[gl_DrawID];

    Vertex_Buffer vertex_buffer = Vertex_Buffer(push_constants.bda_vertex);
    Vertex v = vertex_buffer.vertices[gl_VertexIndex];

    Transform_Buffer transform_buffer = Transform_Buffer(push_constants.bda_transform);
    Transform transform = transform_buffer.transforms[draw.idx_transform];
    mat4 world_matrix = transform.transform; 

    Camera_Data camera = Camera_Data(push_constants.bda_camera);

    vec4 position = vec4(v.position, 1.0);
    vec4 world_pos = world_matrix * position;

    out_material_index = draw.idx_material_instance;
    gl_Position = camera.view_proj * world_matrix * vec4(v.position, 1.0);
}