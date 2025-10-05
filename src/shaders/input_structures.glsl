layout(buffer_reference, scalar) readonly buffer CameraData {
	mat4 view;
	mat4 proj;
	mat4 view_proj;
};

layout(buffer_reference, scalar) readonly buffer MaterialData { 
	vec4 color_factors;
};

layout(push_constant) uniform Push_Constants {
    uint64_t vertex_address;
    uint64_t transform_address;
    uint64_t material_address;
    uint64_t camera_data_address;
    uint color_texture_index;
    uint sampler_index;
} push_constants;

layout(set = 0, binding = 0) uniform texture2D images[];
layout(set = 1, binding = 0) uniform sampler samplers[];