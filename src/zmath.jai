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

magnitude :: (r: Rotor) -> float {
	return sqrt(square(r.scalar) + square(r.xy) + square(r.yz) + square(r.xz));
}

normalize :: (r: Rotor) -> Rotor {
    m := magnitude(r);
    return .{r.scalar/m, r.xy/m, r.yz/m, r.xz/m};
}

make_rotor :: (axis: Vector3, angle: float) -> Rotor {
	c := sin(angle/2)*axis;
	return .{cos(angle/2), c.z, c.x, c.y};
}

make_rotor :: (from: Vector3, to: Vector3) -> Rotor {
	dot := dot_product(to, from);
	 if dot < -0.9999 {
        // Vectors are opposite so rotate 180° around any perpendicular axis
        perp := perpendicular_vector(from);
        return make_rotor(perp, PI);
    }

	wedge := cross_product(to, from);
	r := Rotor.{1 + dot, wedge.x, wedge.y, wedge.z};
	return normalize(r);
}

perpendicular_vector :: (v: Vector3) -> Vector3 {
    if abs(v.x) > 0.9 {
        return normalize(cross_product(v, .{0, 1, 0}));
    } else {
        return normalize(cross_product(v, .{1, 0, 0}));
    }
}

quat_to_rot :: (q: Quaternion) -> Rotor {
	r : Rotor;
	r.scalar 	= q.w;
	r.xy		= q.z;
	r.yz		= q.x;
	r.xz		= q.y;
	return r;
}

// Won't work right now because elements aren't in the right order
quat_to_rot :: (src: *Quaternion, dest: *Rotor) {
	memcpy(dest, src, size_of(Quaternion)); // Quat and Rot are the same size so either works
}

rot_to_quat :: (r: Rotor) -> Quaternion {
	q : Quaternion;
	q.w		= r.scalar;
	q.x		= r.yz;
	q.y		= r.xz;
	q.z		= r.xy;
	return q;
}

/*
normalize :: (r: *Rotor) {
	<<r = r / sqrt(square(r.scalar) + square(r.xy) + square(r.yz) + square(r.xz));
}

normalize_copy :: (r: Rotor) -> Rotor{
	return r / sqrt(square(r.scalar) + square(r.xy) + square(r.yz) + square(r.xz));
}*/