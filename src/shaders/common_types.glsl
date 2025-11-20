#extension GL_EXT_shader_explicit_arithmetic_types : require
#extension GL_EXT_scalar_block_layout : require

layout(buffer_reference, scalar) readonly buffer Render_Globals {
	uint resolution_x;
    uint resolution_y;
};

layout(buffer_reference, scalar) readonly buffer Camera_Data {
	mat4 view;
	mat4 proj;
	mat4 view_proj;
};

struct Transform {
    mat4 transform;
    uint64_t parent_address;
    uint8_t padding[8];
};
layout(buffer_reference, scalar) readonly buffer Transform_Buffer {
    Transform transform;
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

struct Material_Instance {
    vec4 color_factors;
    uint albedo_image_index;
    uint albedo_sampler_index;
    uint8_t type;
    uint8_t padding[4];
};
layout(buffer_reference, scalar) readonly buffer Material_Buffer {
    Material_Instance materials[];
};
