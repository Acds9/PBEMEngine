#extension GL_EXT_shader_explicit_arithmetic_types : require

layout(buffer_reference, scalar) readonly buffer CameraData {
	mat4 view;
	mat4 proj;
	mat4 view_proj;
};

layout(buffer_reference, scalar) readonly buffer MaterialData { 
	vec4 color_factors;
    uint albedo_image_index;
	uint albedo_sampler_index;
};

struct PointLight {
    vec3 position;
    float radius; 
    vec4 color;
};

layout(buffer_reference, scalar) readonly buffer Point_Light_Data { 
    PointLight lights[];
};

struct Transform {
    mat4 transform;
    uint64_t parent_address;
    uint8_t padding[8];
};

layout(push_constant) uniform PushConstants {
    uint64_t vertex_address;
    uint64_t transform_address;
    uint64_t material_address;
    uint64_t camera_data_address;
    uint64_t point_lights_address;
    uint     point_lights_count;
} push_constants;

layout(set = 0, binding = 0) uniform texture2D images[];
layout(set = 1, binding = 0) uniform sampler samplers[];