pack_unorm_4x8 :: (v: Vector4) -> u32 {
	r := cast,no_check(u32)(clamp(v.x, 0, 1) * 255 + 0.5); // +0.5 for rounding
	g := cast,no_check(u32)(clamp(v.y, 0, 1) * 255 + 0.5);
	b := cast,no_check(u32)(clamp(v.z, 0, 1) * 255 + 0.5);
	a := cast,no_check(u32)(clamp(v.w, 0, 1) * 255 + 0.5);

	return r | (g << 8) | (b << 16) | (a << 24);
}

unpack_unorm_4x8 :: (packed: u32) -> Vector4 {
	v : Vector4;
	v.x = cast(float)(packed & 0xFF) / 255.0;
    v.y = cast(float)((packed >> 8) & 0xFF) / 255.0;
    v.z = cast(float)((packed >> 16) & 0xFF) / 255.0;
    v.w = cast(float)((packed >> 24) & 0xFF) / 255.0;
    return v;
}

Rotor	:: struct {
	scalar	: float;
	xy		: float;
	yz		: float;
	xz		: float;
}