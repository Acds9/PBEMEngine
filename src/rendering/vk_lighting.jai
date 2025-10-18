LIGHT_TYPE :: enum u8 {
	POINT;
	SPOT;
	DIRECTIONAL;
}

Point_Light :: struct {
	position	: Vector3;
	radius		: float32;
	color		: Color; // r g b a where a is intensity
}