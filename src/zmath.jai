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
ROTOR_IDENTITY :: Rotor.{1, 0, 0, 0};

operator * :: (r1: Rotor, r2: Rotor) -> Rotor {
    return .{
        r1.scalar*r2.scalar - r1.xy*r2.xy - r1.yz*r2.yz - r1.xz*r2.xz,
        r1.scalar*r2.xy + r1.xy*r2.scalar + r1.yz*r2.xz - r1.xz*r2.yz,
        r1.scalar*r2.yz + r1.yz*r2.scalar + r1.xz*r2.xy - r1.xy*r2.xz,
        r1.scalar*r2.xz + r1.xz*r2.scalar + r1.xy*r2.yz - r1.yz*r2.xy
    };
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
	r := Rotor.{1 + dot, wedge.z, wedge.x, wedge.y};
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

rotate :: (v: Vector3, r: Rotor) -> Vector3 {
    // Extract bivector as a pseudo-vector for cross product
    bivec := Vector3.{r.yz, r.xz, r.xy};
    
    // Standard quaternion-style rotation formula
    t := cross_product(bivec, v) * 2.0;
    return v + t * r.scalar + cross_product(bivec, t);
}

inverse :: (r: Rotor) -> Rotor {
    return .{r.scalar, -r.xy, -r.yz, -r.xz};
}

slerp :: (r1: Rotor, r2: Rotor, t: float) -> Rotor {
    dot := r1.scalar*r2.scalar + r1.xy*r2.xy + r1.yz*r2.yz + r1.xz*r2.xz;
    
    r2_adjusted := r2;
    if dot < 0 {
        r2_adjusted = .{-r2.scalar, -r2.xy, -r2.yz, -r2.xz};
        dot = -dot;
    }
    
    if dot > 0.9995 {
        // Linear interpolation for very close rotors
        result := Rotor.{
            lerp(r1.scalar, r2_adjusted.scalar, t),
            lerp(r1.xy, r2_adjusted.xy, t),
            lerp(r1.yz, r2_adjusted.yz, t),
            lerp(r1.xz, r2_adjusted.xz, t)
        };
        return normalize(result);
    }
    
    angle := acos(dot);
  /*  return add_scaled(r1, sin((1-t)*angle)/sin(angle), 
                      r2_adjusted, sin(t*angle)/sin(angle));*/
}