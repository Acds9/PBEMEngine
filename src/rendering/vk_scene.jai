MESH_BUFFER_SIZE 		:: 8*1024*1024; // 8MB
TRANSFORM_BUFFER_SIZE 	:: 8*1024*1024; 
LIGHT_BUFFER_SIZE 		:: 8*1024*1024;
MAX_LIGHTS 				:: 8192;

ZScene :: struct {
		
	////////////////// GEOMETRY /////////////////////////////////
	mesh_instances	: Staged_Uniform_Storage_Buffer;
	mesh_transforms	: Staged_Uniform_Storage_Buffer;

	////////////////// LIGHT ////////////////////////////////////
	point_lights	: Staged_Uniform_Storage_Buffer;

	Mesh_Queue_Entry :: struct {
		mesh_instance 	: Mesh_Instance;
		transform		: Render_Transform;
		idx_ptr			: *u32;
		visible			: bool;
	}
	mesh_add_queue		: [..][..]Mesh_Queue_Entry;
	mesh_remove_queue	: [..][..]u32;
	
	Light_Queue_Entry :: struct {
		light			: Point_Light; // Right now it's just this, but in the future we'll have transforms for lights to uniformly handle point, spot, etc lights
		idx_ptr			: *u32;
		visible			: bool;
	}
	light_add_queue		: [..][..]Light_Queue_Entry;
	light_remove_queue	: [..][..]u32;

	bvh_system 			: LBVH_System;
}

create_scene :: (allocator: VmaAllocator, device: VkDevice) -> ZScene { // Like in create_world, compiler NRVO
	scene : ZScene;
	scene.mesh_instances = make_staged_uniform_storage_buffer(VMA_ALLOCATOR, MESH_BUFFER_SIZE, size_of(Mesh_Instance), .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, true, device, "mesh_instances buffer");

	scene.mesh_transforms = make_staged_uniform_storage_buffer(VMA_ALLOCATOR, TRANSFORM_BUFFER_SIZE, size_of(Render_Transform), .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, false, device, "mesh_transforms buffer");

	scene.point_lights = make_staged_uniform_storage_buffer(VMA_ALLOCATOR, LIGHT_BUFFER_SIZE, size_of(Point_Light), .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, true, device, "point_lights buffer");

	lane_count := GAME_INSTANCE.lane_system.lane_count;
	array_resize(*scene.mesh_add_queue, lane_count);
	array_resize(*scene.mesh_remove_queue, lane_count);
	array_resize(*scene.light_add_queue, lane_count);
	array_resize(*scene.light_remove_queue, lane_count);
	
	scene.bvh_system.init(*scene.bvh_system);
	return scene;
}

destroy :: (using scene: *ZScene) {
	destroy(*mesh_instances);
	destroy(*mesh_transforms);
	destroy(*point_lights);
	for *arr: mesh_add_queue {
		array_free(<<arr);
	}
	array_free(mesh_add_queue);
	for *arr: mesh_remove_queue {
		array_free(<<arr);
	}
	array_free(mesh_remove_queue);
	for *arr: light_add_queue {
		array_free(<<arr);
	}
	array_free(light_add_queue);
	for *arr: light_remove_queue {
		array_free(<<arr);
	}
	array_free(light_remove_queue);
	destroy(*bvh_system);
}

scene_tick :: (game_world: *Game_World, delta_time: float32) {
	build_bvh(game_world);
}

add_scene_mesh :: (scene: *ZScene, mesh: *Mesh_Asset, local_transform: Matrix4, idx_ptr: *u32, visible: bool = true, parent_transform: u32 = U32_MAX, material_overrides: *[8]u32 = null) {
	queue_entry	: ZScene.Mesh_Queue_Entry;
	queue_entry.idx_ptr = idx_ptr;
	queue_entry.visible = visible;

	mesh_instance 	: Mesh_Instance;
	mesh_instance.idx_mesh_asset = mesh.mesh_index;
	mesh_instance.idx_aabb = mesh.idx_aabb;
	mesh_instance.idx_geo_surface = mesh.idx_geo_surface;
	mesh_instance.geo_surface_count = mesh.geo_surface_count;
	if material_overrides {
		mesh_instance.material_overrides = <<material_overrides;
	}
	queue_entry.mesh_instance = mesh_instance;
	

	render_transform : Render_Transform;
	render_transform.local_transform = local_transform;
	render_transform.parent_idx = parent_transform;
	queue_entry.transform = render_transform;

	
	array_add(*scene.mesh_add_queue[context.thread_index], queue_entry);
}

add_scene_mesh :: (scene: *ZScene, mesh: *Mesh_Asset, transform: Transform, idx_ptr: *u32, visible: bool = true, parent_transform: u32 = 0, material_overrides: *[8]u32 = null) {
	transform_to_matrix4(transform);
	add_scene_mesh(scene, mesh, transform_to_matrix4(transform), idx_ptr, visible, parent_transform, material_overrides);
}

remove_scene_mesh :: (scene: *ZScene, idx: u32) {
    scene.mesh_transforms.buffer_remove(*scene.mesh_transforms, idx);
    scene.mesh_instances.buffer_remove(*scene.mesh_instances, idx);
}

add_scene_point_light :: (scene: *ZScene, light: Point_Light, idx_ptr: *u32, visible: bool = true) {
	queue_entry : ZScene.Light_Queue_Entry;
	queue_entry.light = light;
	queue_entry.idx_ptr = idx_ptr;
	queue_entry.visible = visible;
	array_add(*scene.light_add_queue[context.thread_index], queue_entry);
}

render_get_mesh_instance :: (scene: *ZScene, instance_idx: u32) -> *Mesh_Instance {
	mesh_instances := cast(*Mesh_Instance)scene.mesh_instances.staging_buffer.info.pMappedData;
  	return *mesh_instances[instance_idx];
}

render_set_transform :: (scene: *ZScene, transform_idx: u32, new_transform: *Matrix4) {
    transforms := cast(*Render_Transform)scene.mesh_transforms.staging_buffer.info.pMappedData;
    transforms[transform_idx].local_transform = <<new_transform;
}

render_get_transform :: (scene: *ZScene, transform_idx: u32) -> *Render_Transform {
	transforms := cast(*Render_Transform)scene.mesh_transforms.staging_buffer.info.pMappedData;
    return *transforms[transform_idx];
}

render_get_light :: (scene: *ZScene, instance_idx: u32) -> *Point_Light {
	lights := cast(*Point_Light)scene.point_lights.staging_buffer.info.pMappedData;
  	return *lights[instance_idx];
}

process_scene_arrays :: (using scene: *ZScene) {
	for *lane: mesh_add_queue {
		for *mesh: <<lane {
			mesh.mesh_instance.idx_transform = scene.mesh_transforms.allocate(*scene.mesh_transforms, mesh.transform);
			<<mesh.idx_ptr = scene.mesh_instances.allocate(*scene.mesh_instances, mesh.mesh_instance, mesh.visible); // Set the value of the idx pointer that was passed
		}
	}
	for *lane: light_add_queue {
		for *light: <<lane {
			<<light.idx_ptr = scene.point_lights.allocate(*scene.point_lights, light.light, light.visible);
		}
	}
	for *lane: mesh_remove_queue {
		for idx: <<lane {
			scene.mesh_transforms.buffer_remove(*scene.mesh_transforms, idx);

    		scene.mesh_instances.buffer_remove(*scene.mesh_instances, idx);
			scene.mesh_instances.set_visibility_idx(*scene.mesh_instances, idx, false);
		}
	}
	for *lane: light_remove_queue {
		for idx: <<lane {
			scene.point_lights.buffer_remove(*scene.point_lights, idx);
			scene.point_lights.set_visibility_idx(*scene.point_lights, idx, false);
		}
	}
	narrow(#code{
      for *lane: mesh_add_queue     array_reset(lane);
      for *lane: mesh_remove_queue  array_reset(lane);
      for *lane: light_add_queue    array_reset(lane);
      for *lane: light_remove_queue array_reset(lane);
  	});
}