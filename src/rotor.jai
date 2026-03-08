QUAT_IDENTITY :: Quaternion.{0,0,0,1};
ROTOR_IDENTITY :: Rotor.{1, 0, 0, 0};

Rotor :: struct @serialize {
	scalar	: float;
	xy		: float;
	yz		: float;
	xz		: float;
}

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

make_rotor_from_axis :: (plane: Vector3, angle: float) -> Rotor {
    c := sin(angle/2);
    return .{cos(angle/2), c * plane.z, c * plane.x, c * plane.y};
}

make_rotor :: (from: Vector3, to: Vector3) -> Rotor {
	dot := dot_product(to, from);
	 if dot < -0.9999 {
        // Vectors are opposite so rotate 180° around any perpendicular axis
        perp := perpendicular_vector(from);
        return make_rotor_from_axis(perp, PI);
    }

	wedge := cross_product(to, from);
	r := Rotor.{1 + dot, wedge.z, wedge.x, wedge.y};
	return normalize(r);
}

add_angular_delta :: (orientation: Rotor, angular_delta: Vector3, dt: float) -> Rotor {
    angle := length(angular_delta) * dt;
    if angle < 0.0001 return orientation;
    
    axis := angular_delta / (angle / dt);
    delta := make_rotor(axis, angle);
    return normalize(orientation * delta);
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