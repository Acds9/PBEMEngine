Color :: struct  {
	r, g, b, a : float32;
}

COLOR_BLACK		:: Color.{0, 0, 0, 1};
COLOR_DARK_GREY :: Color.{0.01,0.01,0.01,1};
COLOR_GREY 		:: Color.{.5,.5,.5,1};
COLOR_WHITE 	:: Color.{1, 1, 1, 1};
COLOR_MAGENTA 	:: Color.{1, 0, 1, 1};

color_to_r10g10b10a2 :: (using self: *Color) -> u32 {
	r1 := cast,no_check(u32)(clamp(r, 0, 1) * 1023.0);
	g1 := cast,no_check(u32)(clamp(g, 0, 1) * 1023.0);
	b1 := cast,no_check(u32)(clamp(b, 0, 1) * 1023.0);
	a1 := cast,no_check(u32)(clamp(a, 0, 1) * 3.0);
	return r1 | (g1 << 10) | (b1 << 20) | (a1 << 30);
}

color_to_bytes :: (c: Color) -> [4]u8 {
    return .[
        cast,no_check(u8)(clamp(c.r, 0, 1) * 255.0),
        cast,no_check(u8)(clamp(c.g, 0, 1) * 255.0),
        cast,no_check(u8)(clamp(c.b, 0, 1) * 255.0),
        cast,no_check(u8)(clamp(c.a, 0, 1) * 255.0)
    ];
}

color_to_vec4 :: (c: *Color) -> Vector4 {
	return .{c.r, c.g, c.b, c.a};
}

vec4_to_color :: (v: *Vector4) -> Color {
	return .{v.x, v.y, v.z, v.w};
}

color_to_array :: (c: *Color) -> [4]float {
	return .[c.r, c.g, c.b, c.a];
}
