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

layout(push_constant) uniform PushConstants {
    uint64_t vertex_address;
    uint64_t transform_address;
    uint64_t material_address;
    uint64_t camera_data_address;
} push_constants;

layout(set = 0, binding = 0) uniform texture2D images[];
layout(set = 1, binding = 0) uniform sampler samplers[];