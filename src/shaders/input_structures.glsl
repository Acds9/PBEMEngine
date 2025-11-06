#extension GL_EXT_shader_explicit_arithmetic_types : require
#extension GL_EXT_scalar_block_layout : require

layout(buffer_reference, scalar) readonly buffer Camera_Data {
	mat4 view;
	mat4 proj;
	mat4 view_proj;
};

struct PointLight {
    vec3 position;
    float radius; 
    vec4 color;
};

layout(buffer_reference, scalar) readonly buffer Point_Light_Data { 
    PointLight lights[];
};

layout(push_constant, scalar) uniform Push_Constants {
    uint64_t draw_buffer_address;
    uint64_t camera_data_address;
    uint64_t material_buffer_address;
    uint64_t point_lights_address;
    uint point_lights_count;
} push_constants;
