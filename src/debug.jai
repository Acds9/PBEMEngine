DEBUG_SHAPE :: enum {
	POINT;
	LINE;
	CIRCLE;
	MESH;
}

DEBUG_SHAPE_COUNT	:: #run enum_names(DEBUG_SHAPE).count;

DEBUG_BUFFER_SIZE :: 1*1024*1024;
DEBUG_MI_BUFFER_SIZE :: 1*1024*1024;

Debug_Material_Instance :: struct {
	color_factors			: Vector4;
}

Debug_System :: struct {
	point_instances 			: Staged_Array_Buffer;
	mesh_instances				: Staged_Array_Buffer;
	mesh_transforms				: Staged_Array_Buffer;

	point_material_instances 	: Staged_Array_Buffer;
	mesh_material_instances		: Staged_Array_Buffer; 

	m_debug_point				: Material_Pipeline_Debug_Point;
	mi_debug_point				: u32;					
	m_debug_wireframe			: Material_Pipeline_Debug_Wireframe;
	mi_debug_wireframe 			: u32;

	transfer :: (using self: *Debug_System, cmd: VkCommandBuffer) {
		point_instances.transfer(*point_instances, cmd);
		mesh_instances.transfer(*mesh_instances, cmd);
		mesh_transforms.transfer(*mesh_transforms, cmd);

		point_material_instances.transfer(*point_material_instances, cmd);
		mesh_material_instances.transfer(*mesh_material_instances, cmd);
	}

	reset :: (using self: *Debug_System) {
		point_instances.reset(*point_instances);
		mesh_instances.reset(*mesh_instances);
		mesh_transforms.reset(*mesh_transforms);

		point_material_instances.reset(*point_material_instances);
		mesh_material_instances.reset(*mesh_material_instances);
	}
}

create_debug_system :: (allocator: VmaAllocator, device: VkDevice) -> Debug_System {
	system : Debug_System;

	system.point_instances = make_staged_array_buffer(VMA_ALLOCATOR, DEBUG_BUFFER_SIZE, size_of(Debug_Point), .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, device, "debug_point_instances buffer");
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, *system.point_instances);

	system.mesh_instances = make_staged_array_buffer(VMA_ALLOCATOR, DEBUG_BUFFER_SIZE, size_of(Mesh_Instance), .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, device, "debug_mesh_instances buffer");
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, *system.mesh_instances);

	system.mesh_transforms = make_staged_array_buffer(VMA_ALLOCATOR, DEBUG_BUFFER_SIZE, size_of(Render_Transform), .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, device, "debug_mesh_transforms buffer");
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, *system.mesh_transforms);

	system.point_material_instances = make_staged_array_buffer(VMA_ALLOCATOR, DEBUG_MI_BUFFER_SIZE, size_of(Debug_Material_Instance), .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, device, "debug_point_mi buffer");
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, *system.point_material_instances);

	system.mesh_material_instances = make_staged_array_buffer(VMA_ALLOCATOR, DEBUG_MI_BUFFER_SIZE, size_of(Debug_Material_Instance), .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, device, "debug_mesh_mi buffer");
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, *system.mesh_material_instances);
	
	return system;
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

debug_draw_point :: (zr: *ZRenderer, position: Vector3, size: float, color: Vector4) {
	shape_buffer := *zr.debug_system.point_instances; // Not using the debug point materials for now
	point := Debug_Point.{position, size, color};
	shape_buffer.allocate(shape_buffer, point);
}

debug_draw_sphere :: (zr: *ZRenderer, position: Vector3, size: float, color: Vector4) {
	mesh, found := table_find(*ZRENDERER.mesh_map, "debug_sphere");
	if !found {
		print("WARNING: Could not find % mesh\n", "debug_sphere");
	}

	debug_system := *zr.debug_system;

	material_data : Debug_Material_Instance;
	material_data.color_factors = color;
	material_index := debug_system.m_debug_wireframe.create_material_instance(*debug_system.m_debug_wireframe, zr, *material_data);

	mesh_render : Mesh_Instance; 
	mesh_render.mesh_asset = mesh;
	mesh_render.material_overrides = .[material_index,0,0,0,0,0,0,0];
	
	render_transform : Render_Transform;
	transform := Transform.{position, ROTOR_IDENTITY, VECTOR_ONE * size};
	render_transform.local_transform = transform_to_matrix4(transform);
	mesh_render.transform_address = debug_system.mesh_transforms.allocate(*debug_system.mesh_transforms, render_transform);
	debug_system.mesh_instances.allocate(*debug_system.mesh_instances, mesh_render);
}