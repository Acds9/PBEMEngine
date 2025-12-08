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

DEBUG_VIEW_MODE :: enum s32 {
	NONE;
	WIREFRAME;
	LIGHT_CLUSTER;
}

DEBUG_LIGHT_CLUSTER_MODE :: enum s32 {
	NONE;
	DEPTH_SLICE;
	DEPTH_RAINBOW;
	UV;
	HEATMAP;
}

Debug_System :: struct {
	point_instances 			: Staged_Array_Buffer;
	mesh_instances				: Staged_Array_Buffer;
	mesh_transforms				: Staged_Array_Buffer;

	mesh_material_instances		: Staged_Array_Buffer; 

	m_debug_point				: Material_Pipeline_Debug_Point;
	mi_debug_point				: u32;
	m_debug_wireframe			: Material_Pipeline_Debug_Wireframe;
	mi_debug_wireframe 			: u32;

	transfer :: (using self: *Debug_System, cmd: VkCommandBuffer) {
		point_instances.transfer(*point_instances, cmd);
		mesh_instances.transfer(*mesh_instances, cmd);
		mesh_transforms.transfer(*mesh_transforms, cmd);

		mesh_material_instances.transfer(*mesh_material_instances, cmd);
	}

	reset :: (using self: *Debug_System) {
		point_instances.reset(*point_instances);
		mesh_instances.reset(*mesh_instances);
		mesh_transforms.reset(*mesh_transforms);

		mesh_material_instances.reset(*mesh_material_instances);
	}

	// Debug State
	view_mode			: DEBUG_VIEW_MODE;
	light_cluster_mode	: DEBUG_LIGHT_CLUSTER_MODE;

	light_radius_sphere	: bool;
	mesh_aabb			: bool;

}

create_debug_system :: (allocator: VmaAllocator, device: VkDevice) -> Debug_System {
	system : Debug_System;

	system.point_instances = make_staged_array_buffer(VMA_ALLOCATOR, DEBUG_BUFFER_SIZE, size_of(Debug_Point), .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, device, "debug_point_instances buffer");
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, *system.point_instances);

	system.mesh_instances = make_staged_array_buffer(VMA_ALLOCATOR, DEBUG_BUFFER_SIZE, size_of(Mesh_Instance), .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, device, "debug_mesh_instances buffer");
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, *system.mesh_instances);

	system.mesh_transforms = make_staged_array_buffer(VMA_ALLOCATOR, DEBUG_BUFFER_SIZE, size_of(Render_Transform), .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, device, "debug_mesh_transforms buffer");
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, *system.mesh_transforms);

	system.mesh_material_instances = make_staged_array_buffer(VMA_ALLOCATOR, DEBUG_MI_BUFFER_SIZE, size_of(Debug_Material_Instance), .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, device, "debug_mesh_mi buffer");
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, *system.mesh_material_instances);
	
	return system;
}

generate_debug_mesh_draws :: (zr: *ZRenderer, draw_buffer: *Staged_Array_Buffer) {
	count := zr.debug_system.mesh_instances.count;
	if count == 0 {
		return;
	}
	mapped_data := cast,no_check(*Mesh_Instance)zr.debug_system.mesh_instances.staging_buffer.info.pMappedData;
	for 0..count-1 {
		mesh_instance : *Mesh_Instance = *mapped_data[it];
		geo_surface_data := cast,no_check(*Geo_Surface)zr.geometry_pool.geo_surface_buffer.staging_buffer.info.pMappedData;
		for 0..mesh_instance.geo_surface_count-1 {
			geo_surface := *geo_surface_data[mesh_instance.idx_geo_surface + it];
		
			command : Draw_Command;
			command.draw.indexCount = geo_surface.index_count;
			command.draw.instanceCount = 1;
			command.draw.firstIndex = geo_surface.idx_index;
			command.draw.vertexOffset = xx,no_check geo_surface.idx_vertex;
			command.draw.firstInstance = 0;
			command.idx_transform = mesh_instance.idx_transform;
			command.idx_material_instance = mesh_instance.material_overrides[it];
			
			draw_buffer.allocate(draw_buffer, command);
		}
		
	}
}

Debug_Point :: struct {
	color		: Vector4;
	position	: Vector3;
	size 		: float;
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
	point_buffer := *zr.debug_system.point_instances;

	point := Debug_Point.{color, position, size};
	point_buffer.allocate(point_buffer, point);
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
	mesh_render.idx_mesh_asset = mesh.mesh_index;
	mesh_render.material_overrides = .[material_index,0,0,0,0,0,0,0];
	mesh_render.idx_geo_surface = mesh.idx_geo_surface;
	mesh_render.geo_surface_count = mesh.geo_surface_count;
	
	render_transform : Render_Transform;
	transform := Transform.{position, ROTOR_IDENTITY, VECTOR_ONE * size};
	render_transform.local_transform = transform_to_matrix4(transform);

	mesh_render.idx_transform = debug_system.mesh_transforms.allocate(*debug_system.mesh_transforms, render_transform);
	debug_system.mesh_instances.allocate(*debug_system.mesh_instances, mesh_render);
}

Debug_Globals :: struct {
	draw_light_clusters	: bool;
	light_cluster_color	: Vector4;
}