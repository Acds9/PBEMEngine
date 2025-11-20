AXIS_FORWARD	:: Vector3.{1,0,0};
AXIS_RIGHT		:: Vector3.{0,1,0};
AXIS_UP			:: Vector3.{0,0,1};

NEAR_PLANE		: float : 0.1;
FAR_PLANE		: float : 1000.0;


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

// Init camera with default values
init_camera :: (camera: *Render_Camera) {
	camera.position = .{-5, 0, 0};
	camera.rotation = ROTOR_IDENTITY;
	camera.fov = 95.0;
	camera.near_plane = NEAR_PLANE;
	camera.far_plane = FAR_PLANE;
}

