VECTOR_ZERO :: Vector3.{0,0,0};
VECTOR_ONE :: Vector3.{1,1,1};

TRANSFORM_IDENTITY :: Transform.{VECTOR_ZERO, ROTOR_IDENTITY, VECTOR_ONE};

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

perpendicular_vector :: (v: Vector3) -> Vector3 {
    if abs(v.x) > 0.9 {
        return normalize(cross_product(v, .{0, 1, 0}));
    } else {
        return normalize(cross_product(v, .{1, 0, 0}));
    }
}

Transform :: struct {
	position	: Vector3;
	rotation	: Rotor;
	scale		: Vector3;
}

transform_to_matrix4 :: (t: Transform) -> Matrix4 {
    // Rotate the standard basis vectors by the rotor
    x_axis := rotate(Vector3.{1, 0, 0}, t.rotation);
    y_axis := rotate(Vector3.{0, 1, 0}, t.rotation);
    z_axis := rotate(Vector3.{0, 0, 1}, t.rotation);
    
    // Apply scale to the rotated basis vectors
    x_axis *= t.scale.x;
    y_axis *= t.scale.y;
    z_axis *= t.scale.z;
    
    // Construct row-major matrix, each row represents a transformed basis vector
    m: Matrix4;
    m._11 = x_axis.x;  m._12 = x_axis.y;  m._13 = x_axis.z;  m._14 = 0;
    m._21 = y_axis.x;  m._22 = y_axis.y;  m._23 = y_axis.z;  m._24 = 0;
    m._31 = z_axis.x;  m._32 = z_axis.y;  m._33 = z_axis.z;  m._34 = 0;
    m._41 = t.position.x;  m._42 = t.position.y;  m._43 = t.position.z;  m._44 = 1;
    
    return m;
}

matrix3x3_to_rotor :: (x_axis: Vector3, y_axis: Vector3, z_axis: Vector3) -> Rotor {
    // Adapted from Shepperd's quaternion extraction method
    trace := x_axis.x + y_axis.y + z_axis.z;
    r: Rotor;
    
    if trace > 0 {
        s := sqrt(trace + 1) * 2;  // s = 4 * scalar
        r.scalar = 0.25 * s;
        r.yz = (y_axis.z - z_axis.y) / s;  // quat.x
        r.xz = (z_axis.x - x_axis.z) / s;  // quat.y
        r.xy = (x_axis.y - y_axis.x) / s;  // quat.z
    } else if x_axis.x > y_axis.y && x_axis.x > z_axis.z {
        s := sqrt(1 + x_axis.x - y_axis.y - z_axis.z) * 2;  // s = 4 * yz
        r.scalar = (y_axis.z - z_axis.y) / s;
        r.yz = 0.25 * s;
        r.xz = (x_axis.y + y_axis.x) / s;
        r.xy = (z_axis.x + x_axis.z) / s;
    } else if y_axis.y > z_axis.z {
        s := sqrt(1 + y_axis.y - x_axis.x - z_axis.z) * 2;  // s = 4 * xz
        r.scalar = (z_axis.x - x_axis.z) / s;
        r.yz = (x_axis.y + y_axis.x) / s;
        r.xz = 0.25 * s;
        r.xy = (y_axis.z + z_axis.y) / s;
    } else {
        s := sqrt(1 + z_axis.z - x_axis.x - y_axis.y) * 2;  // s = 4 * xy
        r.scalar = (x_axis.y - y_axis.x) / s;
        r.yz = (z_axis.x + x_axis.z) / s;
        r.xz = (y_axis.z + z_axis.y) / s;
        r.xy = 0.25 * s;
    }
    
    return normalize(r);
}

matrix4_to_transform :: (m: Matrix4) -> Transform {
    t: Transform;
    
    // Extract translation from last row
    t.position = Vector3.{m._41, m._42, m._43};
    
    // Extract the basis vectors
    x_axis := Vector3.{m._11, m._12, m._13};
    y_axis := Vector3.{m._21, m._22, m._23};
    z_axis := Vector3.{m._31, m._32, m._33};
    
    // Extract scale from the length of basis vectors
    t.scale.x = length(x_axis);
    t.scale.y = length(y_axis);
    t.scale.z = length(z_axis);
    
    // Normalize to get pure rotation matrix
    if t.scale.x != 0  x_axis /= t.scale.x;
    if t.scale.y != 0  y_axis /= t.scale.y;
    if t.scale.z != 0  z_axis /= t.scale.z;
    
    // Convert rotation matrix to rotor
    t.rotation = matrix3x3_to_rotor(x_axis, y_axis, z_axis);
    
    return t;
}