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
	}
	mesh_queue		: [..][..]Mesh_Queue_Entry;
	
	Light_Queue_Entry :: struct {
		light		: Point_Light; // Right now it's just this, but in the future we'll have transforms for lights to uniformly handle point, spot, etc lights
		idx_ptr		: *u32;
	}
	light_queue		: [..][..]Light_Queue_Entry;
}

create_zscene :: (allocator: VmaAllocator, device: VkDevice) -> ZScene {
	scene : ZScene;

	scene.mesh_instances = make_staged_uniform_storage_buffer(VMA_ALLOCATOR, MESH_BUFFER_SIZE, size_of(Mesh_Instance), .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, device, "mesh_instances buffer");
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, *scene.mesh_instances);

	scene.mesh_transforms = make_staged_uniform_storage_buffer(VMA_ALLOCATOR, TRANSFORM_BUFFER_SIZE, size_of(Render_Transform), .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, device, "mesh_transforms buffer");
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, *scene.mesh_transforms);
	
	scene.point_lights = make_staged_uniform_storage_buffer(VMA_ALLOCATOR, LIGHT_BUFFER_SIZE, size_of(Point_Light), .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, device, "point_lights buffer");
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, *scene.point_lights);

	lane_count := GAME_INSTANCE.lane_system.lane_count;
	array_resize(*scene.mesh_queue, lane_count);
	array_resize(*scene.light_queue, lane_count);
	
	return scene;
}

add_scene_mesh :: (scene: *ZScene, mesh: *Mesh_Asset, local_transform: Matrix4, idx_ptr: *u32, parent_transform: u32 = U32_MAX, material_overrides: *[8]u32 = null) {
	queue_entry	: ZScene.Mesh_Queue_Entry;
	queue_entry.idx_ptr = idx_ptr;

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

	
	array_add(*scene.mesh_queue[context.thread_index], queue_entry);
}

add_scene_mesh :: (scene: *ZScene, mesh: *Mesh_Asset, transform: Transform, idx_ptr: *u32, parent_transform: u32 = 0, material_overrides: []u32 = .[]) {
	transform_to_matrix4(transform);
	add_scene_mesh(scene, mesh, transform_to_matrix4(transform), idx_ptr, parent_transform);
}

remove_scene_mesh :: (scene: *ZScene, idx: u32) {
    scene.mesh_transforms.buffer_remove(*scene.mesh_transforms, idx);
    scene.mesh_instances.buffer_remove(*scene.mesh_instances, idx);
}

add_scene_point_light :: (scene: *ZScene, light: Point_Light, idx_ptr: *u32) {
	queue_entry : ZScene.Light_Queue_Entry;
	queue_entry.light = light;
	queue_entry.idx_ptr = idx_ptr;
	array_add(*scene.light_queue[context.thread_index], queue_entry);
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

process_scene_arrays :: (using scene: *ZScene) {
	for *lane: mesh_queue {
		for *mesh: <<lane {
			mesh.mesh_instance.idx_transform = scene.mesh_transforms.allocate(*scene.mesh_transforms, mesh.transform);
			<<mesh.idx_ptr = scene.mesh_instances.allocate(*scene.mesh_instances, mesh.mesh_instance); // Set the value of the idx pointer that was passed
		}
	}
	for *lane: light_queue {
		for *light: <<lane {
			<<light.idx_ptr = scene.point_lights.allocate(*scene.point_lights, light.light);
		}
	}
	if context.thread_index == 0 {
		array_reset(*mesh_queue);
		array_reset(*light_queue);
	}
}