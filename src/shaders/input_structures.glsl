layout(set = 0, binding = 0) uniform  Scene_Data{   

	mat4 view;
	mat4 proj;
	mat4 view_proj;
	vec4 ambient_color;
	vec4 sunlight_direction; //w for sun power
	vec4 sunlight_color;
} scene_data;

layout(set = 1, binding = 0) uniform Material_Data{   

	vec4 color_factors;
	vec4 blaCKbody_factors;
	
} material_data;

layout(set = 1, binding = 1) uniform sampler2D color_tex;
layout(set = 1, binding = 2) uniform sampler2D blackbody_tex;