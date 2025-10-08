AXIS_FORWARD	:: Vector3.{1,0,0};
AXIS_RIGHT		:: Vector3.{0,1,0};
AXIS_UP			:: Vector3.{0,0,1};


Render_Camera :: struct {
	GPU_Camera_Data :: struct {
		view			: Matrix4;
		proj			: Matrix4;
		view_proj		: Matrix4;
	}
	gpu_data 		: GPU_Camera_Data; // This is uploaded straight to the GPU

	position		: Vector3;
	fov				: float;
	rotation		: Rotor;
	aspect_ratio	: float;
	near_plane		: float;
	far_plane		: float;

	forward			: Vector3;
	right			: Vector3;
	up				: Vector3;

	translate :: (using self: *Render_Camera, translation: Vector3) {
		position += translation;
	}

	rotate :: (using self: *Render_Camera, new_rotation: Rotor) {
		rotation = new_rotation;
	}
}

quaternion_from_axis_angle :: (axis: Vector3, angle: float) -> Quaternion {
    normalized_axis := normalize(axis);
    
    half_angle := angle * 0.5;
    s := sin(half_angle);
    
    result: Quaternion;
    result.x = normalized_axis.x * s;
    result.y = normalized_axis.y * s;
    result.z = normalized_axis.z * s;
    result.w = cos(half_angle);
    
    return result;
}

// Axis must already be normalized
quaternion_from_axis_angle_fast :: (axis: Vector3, angle: float) -> Quaternion {
    half_angle := angle * 0.5;
    s := sin(half_angle);
    
    result: Quaternion;
    result.x = axis.x * s;
    result.y = axis.y * s;
    result.z = axis.z * s;
    result.w = cos(half_angle);
    
    return result;
}

