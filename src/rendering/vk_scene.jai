MESH_BUFFER_SIZE 		:: 8*1024*1024; // 8MB
TRANSFORM_BUFFER_SIZE 	:: 8*1024*1024; 
LIGHT_BUFFER_SIZE 		:: 8*1024*1024;
// TODO: these buffer sizes are all overkill
SCENE_DEBUG_BUFFER_SIZE :: 1*1024*1024;

ZScene :: struct {
		
	////////////////// GEOMETRY /////////////////////////////////
	mesh_instances	: Staged_Uniform_Storage_Buffer;
	mesh_transforms	: Staged_Uniform_Storage_Buffer;

	////////////////// LIGHT ////////////////////////////////////
	point_lights	: Staged_Uniform_Storage_Buffer;

	//////////////////// DEBUG //////////////////////////////////
	debug_point_instances 			: Staged_Uniform_Storage_Buffer;
	debug_mesh_instances			: Staged_Uniform_Storage_Buffer;
	debug_mesh_transforms			: Staged_Uniform_Storage_Buffer;
}

create_zscene :: (allocator: VmaAllocator, device: VkDevice) -> ZScene {
	scene : ZScene;

	scene.mesh_instances = make_staged_uniform_storage_buffer(VMA_ALLOCATOR, MESH_BUFFER_SIZE, size_of(Mesh_Instance), .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, device, "mesh_instances buffer");
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, *scene.mesh_instances);

	scene.mesh_transforms = make_staged_uniform_storage_buffer(VMA_ALLOCATOR, TRANSFORM_BUFFER_SIZE, size_of(Render_Transform), .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, device, "mesh_transforms buffer");
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, *scene.mesh_transforms);
	
	scene.point_lights = make_staged_uniform_storage_buffer(VMA_ALLOCATOR, LIGHT_BUFFER_SIZE, size_of(Point_Light), .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, device, "point_lights buffer");
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, *scene.point_lights);

	scene.debug_point_instances = make_staged_uniform_storage_buffer(VMA_ALLOCATOR, SCENE_DEBUG_BUFFER_SIZE, size_of(Debug_Point), .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, device, "debug_point_instances buffer");
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, *scene.debug_point_instances);

	scene.debug_mesh_instances = make_staged_uniform_storage_buffer(VMA_ALLOCATOR, SCENE_DEBUG_BUFFER_SIZE, size_of(Mesh_Instance), .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, device, "debug_mesh_instances buffer");
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, *scene.debug_mesh_instances);

	scene.debug_mesh_transforms = make_staged_uniform_storage_buffer(VMA_ALLOCATOR, SCENE_DEBUG_BUFFER_SIZE, size_of(Render_Transform), .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, device, "debug_mesh_transforms buffer");
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, *scene.debug_mesh_transforms);

	return scene;
}

add_scene_mesh :: (scene: *ZScene, mesh: *Mesh_Asset, local_transform: Matrix4, parent_transform: VkDeviceAddress = 0) -> VkDeviceAddress {
	mesh_render : Mesh_Instance;
	mesh_render.mesh_asset = mesh;

	render_transform : Render_Transform;
	render_transform.local_transform = local_transform;
	render_transform.parent_address = parent_transform;

	mesh_render.transform_address = scene.mesh_transforms.allocate(*scene.mesh_transforms, render_transform);

	return scene.mesh_instances.allocate(*scene.mesh_instances, mesh_render);
}

add_scene_mesh :: (scene: *ZScene, mesh: *Mesh_Asset, transform: Transform, parent_transform: VkDeviceAddress = 0) -> VkDeviceAddress {
	transform_to_matrix4(transform);
	return add_scene_mesh(scene, mesh, transform_to_matrix4(transform), parent_transform);
}

remove_scene_mesh :: (scene: *ZScene, address: VkDeviceAddress) {
    scene.mesh_transforms.buffer_remove(*scene.mesh_transforms, address);
    scene.mesh_instances.buffer_remove(*scene.mesh_instances, address);
}

add_scene_point_light :: (scene: *ZScene, light: Point_Light) -> VkDeviceAddress {
	return scene.point_lights.allocate(*scene.point_lights, light);
}

render_get_mesh_instance :: (scene: *ZScene, instance_address: VkDeviceAddress) -> *Mesh_Instance {
	instance_buffer := *scene.mesh_instances.staging_buffer;
	offset := instance_address - instance_buffer.base_address;

	dest_ptr := cast,no_check(*Mesh_Instance)(cast,no_check(*u8)instance_buffer.info.pMappedData + offset);
  	return dest_ptr;
}

render_set_transform :: (scene: *ZScene, mesh_instance: *Mesh_Instance, new_transform: *Matrix4) {
	render_set_transform(scene, mesh_instance.transform_address, new_transform);
}

render_set_transform :: (scene: *ZScene, transform_address: VkDeviceAddress, new_transform: *Matrix4) {
	transform_buffer := *scene.mesh_transforms.staging_buffer;
    offset := transform_address - transform_buffer.base_address;
    
    dest_ptr := cast,no_check(*Render_Transform)(cast,no_check(*u8)transform_buffer.info.pMappedData + offset);
    dest_ptr.local_transform = <<new_transform;
}

render_get_transform :: (scene: *ZScene, transform_address: VkDeviceAddress) -> *Render_Transform {
	transform_buffer := *scene.mesh_transforms.staging_buffer;
    offset := transform_address - transform_buffer.base_address;
    
    dest_ptr := cast,no_check(*Render_Transform)(cast,no_check(*u8)transform_buffer.info.pMappedData + offset);
   	return dest_ptr;
}

render_get_world_transform :: (scene: *ZScene, mesh_instance: *Mesh_Instance) -> Matrix4 {
	return calculate_world_transform(render_get_transform(scene, mesh_instance.transform_address));
}

render_get_local_transform :: (scene: *ZScene, mesh_instance: *Mesh_Instance) -> Matrix4 {
	return render_get_transform(scene, mesh_instance.transform_address).local_transform;
}

clear_debug_buffers :: (using scene: *ZScene) {
	debug_point_instances.reset(*debug_point_instances);			
	debug_mesh_instances.reset(*debug_mesh_instances);	
	debug_mesh_transforms.reset(*debug_mesh_transforms);
}

copy_staging_to_device_buffers :: (using scene: *ZScene, cmd: VkCommandBuffer) {
	mesh_instances.transfer(*mesh_instances, cmd);
	mesh_transforms.transfer(*mesh_transforms, cmd);
	point_lights.transfer(*point_lights, cmd);

	debug_point_instances.transfer(*debug_point_instances, cmd);
	debug_mesh_instances.transfer(*debug_mesh_instances, cmd);
	debug_mesh_transforms.transfer(*debug_mesh_transforms, cmd);

	// Barrier to ensure copies complete before rendering
    barrier : VkMemoryBarrier;
    barrier.sType = .VK_STRUCTURE_TYPE_MEMORY_BARRIER;
    barrier.srcAccessMask = .VK_ACCESS_TRANSFER_WRITE_BIT;
    barrier.dstAccessMask = .VK_ACCESS_SHADER_READ_BIT;
    
    vkCmdPipelineBarrier(cmd, .VK_PIPELINE_STAGE_TRANSFER_BIT, .VK_PIPELINE_STAGE_VERTEX_SHADER_BIT, 0, 1, *barrier, 0, null, 0, null);
}