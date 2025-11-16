#extension GL_EXT_shader_explicit_arithmetic_types : require
#extension GL_EXT_scalar_block_layout : require

layout(buffer_reference, scalar) readonly buffer Point_Data { 
    vec4 color;
    vec3 position;
	float size;
};

struct Debug_Material_Instance {
    vec4 color_factors;
};
layout(buffer_reference, scalar) readonly buffer Debug_Material_Buffer {
    Debug_Material_Instance debug_materials[];
};
