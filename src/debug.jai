DEBUG_SHAPE :: enum {
	POINT;
	LINE;
	SQUARE;
	CIRCLE;
	SPHERE;
	CUBE;
	CONE;
}

Debug_Point :: struct {
	position	: Vector3;
	size 		: float;
	color		: Vector4;
}

Debug_Line :: struct {
	start_position	: Vector3;
	end_position 	: Vector3;
}

Debug_Circle :: struct {
	position	: Vector3;
	normal		: Vector3;
	radius		: float;
}

Debug_Square :: struct {
	position	: Vector3;
	normal		: Vector3;
	radius		: float;
}

Debug_Sphere :: struct {
	position	: Vector3;
	radius		: float;
}

Debug_Cube :: struct {
	radius_x	: float;
	radius_Y	: float;
	radius_Z	: float;
}

Debug_Cone :: struct {
	length		: float;
	half_angle	: float;
}

Debug_Shape_Component :: struct {
	using #as entity_component: Entity_Component;

	type		: DEBUG_SHAPE;
	union {
		point	: Debug_Point;
		line	: Debug_Line;
		square	: Debug_Square;
		circle	: Debug_Circle;
		sphere	: Debug_Sphere;
		cube	: Debug_Cube;
		cone	: Debug_Cone;
	}
}

debug_draw_point :: (scene: *ZScene, position: Vector3, size: float, color: Vector4) {
	shape_buffer := *scene.scene_debug_point_instances;
	point := Debug_Point.{position, size, color};
	shape_buffer.allocate(shape_buffer, point);
}

debug_draw_sphere :: (scene: *ZScene, position: Vector3, size: float, color: Vector4) {
	mesh, found := table_find(*ZRENDERER.mesh_map, "debug_sphere");
	if !found {
		print("WARNING: Could not find % mesh\n", "debug_sphere");
	}

	mesh_render : Mesh_Instance;
	mesh_render.mesh_asset = mesh;

	render_transform : Render_Transform;
	transform := Transform.{position, ROTOR_IDENTITY, VECTOR_ONE * size};
	render_transform.local_transform = transform_to_matrix4(transform);
	render_transform.parent_address = 0;

	transform_buffer := *scene.scene_debug_transforms;
	
	mesh_render.transform_address = transform_buffer.allocate(transform_buffer, render_transform, *mesh_render.generation);

	scene.scene_debug_mesh_instances.allocate(*scene.scene_debug_mesh_instances, mesh_render);
}