DEBUG_SHAPE :: enum {
	POINT;
	LINE;
	MESH;
}

DEBUG_SHAPE_COUNT	:: #run enum_names(DEBUG_SHAPE).count;

DEBUG_BUFFER_SIZE :: 1*1024*1024;
DEBUG_MI_BUFFER_SIZE :: 1*1024*1024;

Debug_Material_Instance :: struct {
	color_factors			: Vector4;
}

DEBUG_MESH_TYPE :: enum s32 {
	SPHERE;
	BOX;
}

debug_mesh_name :: (type: DEBUG_MESH_TYPE) -> string {
	if type =={
		case .SPHERE; return "debug_sphere";
		case .BOX;	return "debug_box";
		case; return "debug_sphere";
	} 
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
	line_instances				: Staged_Array_Buffer;
	mesh_instances				: Staged_Array_Buffer;
	mesh_transforms				: Staged_Array_Buffer;

	mesh_material_instances		: Staged_Array_Buffer; 

	m_debug_point				: Material_Pipeline_Debug_Point;
	mi_debug_point				: u32;
	m_debug_line				: Material_Pipeline_Debug_Line;
	mi_debug_line				: u32;
	m_debug_wireframe			: Material_Pipeline_Debug_Wireframe;
	mi_debug_wireframe 			: u32;
	
	Debug_Shape_Data :: union {
		point	: Debug_Point;
		line	: Debug_Line;
		mesh	: Debug_Mesh;
	}
	Persistent_Debug_Shape :: struct {
		shape_data	: Debug_Shape_Data;
		lifetime	: float;
		type		: DEBUG_SHAPE;
	}

	persistent_debug_shapes		: [DEBUG_SHAPE_COUNT][..]Persistent_Debug_Shape;

	transfer :: (using self: *Debug_System, cmd: VkCommandBuffer) {
		point_instances.transfer(*point_instances, cmd);
		line_instances.transfer(*line_instances, cmd);
		mesh_instances.transfer(*mesh_instances, cmd);
		mesh_transforms.transfer(*mesh_transforms, cmd);

		mesh_material_instances.transfer(*mesh_material_instances, cmd);
	}

	reset :: (using self: *Debug_System) {
		point_instances.reset(*point_instances);
		line_instances.reset(*line_instances);
		mesh_instances.reset(*mesh_instances);
		mesh_transforms.reset(*mesh_transforms);

		mesh_material_instances.reset(*mesh_material_instances);
	}

	// Debug State
	view_mode			: DEBUG_VIEW_MODE;
	light_cluster_mode	: DEBUG_LIGHT_CLUSTER_MODE;

	light_radius_sphere	: bool;
	mesh_aabb			: bool;
	bvh_bounds			: bool;
}

create_debug_system :: (allocator: VmaAllocator, device: VkDevice) -> Debug_System {
	system : Debug_System;

	system.point_instances = make_staged_array_buffer(VMA_ALLOCATOR, DEBUG_BUFFER_SIZE, size_of(Debug_Point), .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, device, "debug_point_instances buffer");
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, *system.point_instances);
	
	system.line_instances = make_staged_array_buffer(VMA_ALLOCATOR, DEBUG_BUFFER_SIZE, size_of(Debug_Line), .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, device, "debug_line_instances buffer");
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, *system.line_instances);

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

debug_tick :: () {
	using ZRENDERER.debug_system;
	reset(*ZRENDERER.debug_system);

	if light_radius_sphere {
		execute_Query_Debug_Draw_Point_Light(*GAME_INSTANCE.active_world.world, #code {
			debug_draw_point(*ZRENDERER, position.value, 5, point_light_component.color); 
			debug_draw_mesh(*ZRENDERER, position.value, ROTOR_IDENTITY, VECTOR_ONE * point_light_component.radius, .SPHERE, point_light_component.color);
		});
	}
	if mesh_aabb {
		execute_Query_Debug_Draw_AABB(*GAME_INSTANCE.active_world.world, #code {
			mesh_data 		:= cast,no_check(*Mesh_Instance) GAME_INSTANCE.active_world.scene.mesh_instances.staging_buffer.info.pMappedData;
			mesh_instance 	:= *mesh_data[mesh_render_proxy_ec.value];
			aabb_data 		:= cast,no_check(*AABB) ZRENDERER.geometry_pool.default_aabb_buffer.staging_buffer.info.pMappedData;
			aabb			:= *aabb_data[mesh_instance.idx_aabb];

			debug_draw_mesh(*ZRENDERER, position.value + aabb.center, rotation.value, aabb.half_extents, .BOX, .{1,1,1,1});
		});
	}
	volume :: (b: Volume_Bounds) -> float {
		e := b.max - b.min;
		return e.x * e.y * e.z;
	}
	if bvh_bounds {
		bvh := *GAME_INSTANCE.active_world.scene.bvh_system;
		for *node: bvh.internal_nodes {
			t := volume(node.bounds) / volume(bvh.scene_bounds); 
   			color := Vector4.{1-t, 0, t, 1};  
			center := node.bounds.min + ((node.bounds.max - node.bounds.min) / 2);
			half_extents := node.bounds.max - center;
			debug_draw_mesh(*ZRENDERER, center, ROTOR_IDENTITY, half_extents, .BOX, color);
		}
		for i: 0..bvh.morton_codes.count-1 {
			center := bvh.morton_codes[i].bounds.min + ((bvh.morton_codes[i].bounds.max - bvh.morton_codes[i].bounds.min) / 2);
			half_extents := bvh.morton_codes[i].bounds.max - center;
			debug_draw_mesh(*ZRENDERER, center, ROTOR_IDENTITY, half_extents, .BOX, .{0,1,0,1});
		}
	}

	delta_time := GAME_INSTANCE.delta_time;
	for *type: persistent_debug_shapes {
		shape_type := cast,no_check(DEBUG_SHAPE) it_index;
		for *shape: <<type {
			if shape_type == {
				case .POINT; {
					point_data := *shape.shape_data.point;
					point_buffer := *ZRENDERER.debug_system.point_instances;

					point_buffer.allocate(point_buffer, point_data);

					shape.lifetime -= xx,no_check delta_time;
				}
				case .LINE; {
					line_data := *shape.shape_data.line;
					line_buffer := *ZRENDERER.debug_system.line_instances;

					GLSL_Line :: struct {
						vertex			: Vector3; // Lines are stored as 1 color 1 vertex and then attached by the shader, so no start+end
						pad0			: u32;
						color			: Vector4;
					}

					start_vertex := GLSL_Line.{line_data.start, 0, line_data.color};
					line_buffer.allocate(line_buffer, start_vertex);
					end_vertex := GLSL_Line.{line_data.end, 0, line_data.color};
					line_buffer.allocate(line_buffer, end_vertex);
					
					shape.lifetime -= xx,no_check delta_time;
				}
				case .MESH; {
					mesh_data := *shape.shape_data.mesh;
					mesh_name := debug_mesh_name(mesh_data.type);
					mesh, found := table_find(*ZRENDERER.mesh_map, mesh_name);
					if !found {
						print("WARNING: Could not find % mesh\n", mesh_name);
					}
					
					debug_system := *ZRENDERER.debug_system;

					material_data : Debug_Material_Instance;
					material_data.color_factors = mesh_data.color;
					material_index := debug_system.m_debug_wireframe.create_material_instance(*debug_system.m_debug_wireframe, *ZRENDERER, *material_data);

					mesh_render : Mesh_Instance; 
					mesh_render.idx_mesh_asset = mesh.mesh_index;
					mesh_render.material_overrides = .[material_index,0,0,0,0,0,0,0];
					mesh_render.idx_geo_surface = mesh.idx_geo_surface;
					mesh_render.geo_surface_count = mesh.geo_surface_count;
	
					render_transform : Render_Transform;
					transform := Transform.{mesh_data.position, mesh_data.rotation, mesh_data.scale};
					render_transform.local_transform = transform_to_matrix4(transform);

					mesh_render.idx_transform = debug_system.mesh_transforms.allocate(*debug_system.mesh_transforms, render_transform);
					debug_system.mesh_instances.allocate(*debug_system.mesh_instances, mesh_render);
					shape.lifetime -= xx,no_check delta_time;
				}
			} 
		}
	}
	for *type: persistent_debug_shapes {
		shape_type := cast,no_check(DEBUG_SHAPE) it_index;
		for *shape: <<type {
			if shape.lifetime < 0 {
				array_unordered_remove_by_index(*<<type, it_index);
			}
		}
	}
}

Debug_Point :: struct {
	color		: Vector4;
	position	: Vector3;
	size 		: float;
}

Debug_Line :: struct {
	start			: Vector3;
	end				: Vector3;
	color			: Vector4;
}

Debug_Mesh :: struct {
	position		: Vector3;
	rotation		: Rotor;
	scale			: Vector3;
	color			: Vector4;
	type			: DEBUG_MESH_TYPE;
}

Debug_Globals :: struct {
	draw_light_clusters	: bool;
	light_cluster_color	: Vector4;
}

debug_draw_point :: (zr: *ZRenderer, position: Vector3, size: float, color: Vector4 = .{1,1,1,1}, lifetime: float = 0) {
	data: Debug_System.Debug_Shape_Data = ---;
    data.point = .{color, position, size};
    array_add(*zr.debug_system.persistent_debug_shapes[DEBUG_SHAPE.POINT], .{data, lifetime, .POINT});
}

debug_draw_line	:: (zr: *ZRenderer, start: Vector3, end: Vector3, color: Vector4 = .{1,1,1,1}, lifetime: float = 0) {
	data: Debug_System.Debug_Shape_Data = ---;
    data.line = .{start, end, color};
    array_add(*zr.debug_system.persistent_debug_shapes[DEBUG_SHAPE.LINE], .{data, lifetime, .LINE});
}

debug_draw_mesh	:: (zr: *ZRenderer, position: Vector3, rotation: Rotor = ROTOR_IDENTITY, scale: Vector3 = .{1,1,1}, type: DEBUG_MESH_TYPE = .SPHERE, color: Vector4 = .{1,1,1,1}, lifetime: float = 0) {
	data: Debug_System.Debug_Shape_Data = ---;
    data.mesh = .{position, rotation, scale, color, type};
    array_add(*zr.debug_system.persistent_debug_shapes[DEBUG_SHAPE.MESH], .{data, lifetime, .MESH});
}