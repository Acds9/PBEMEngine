LIGHT_TYPE :: enum u8 {
	POINT;
	SPOT;
	DIRECTIONAL;
}

// TODO: move this to its own file
Light :: struct {
	position	: Vector3;
	radius		: float32;
	color		: Color; // r g b a where a is intensity
	type		: LIGHT_TYPE;
	direction	: Vector3;
	spot_angle	: float32;
	padding		: Vector4;
}

Light_Cluster :: struct {
	min		: Vector4; // Vector4 for alignement
	max		: Vector4;
}

// To access the clustered light data in the light index buffer
Light_Cluster_Index_Range :: struct {
	offset	: u32;
	count	: u32;
}