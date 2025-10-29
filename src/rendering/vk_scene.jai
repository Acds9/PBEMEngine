MESH_BUFFER_SIZE 		:: 8*1024*1024; // 8MB
TRANSFORM_BUFFER_SIZE 	:: 8*1024*1024; 
LIGHT_BUFFER_SIZE 		:: 8*1024*1024;
// TODO: these buffer sizes are all overkill
SCENE_DEBUG_BUFFER_SIZE :: 1*1024*1024;

ZScene :: struct {
	
	mesh_instances	: Staged_Uniform_Storage_Buffer;
	mesh_transforms	: Staged_Uniform_Storage_Buffer;
	point_lights	: Staged_Uniform_Storage_Buffer;

	//////////////////// DEBUG //////////////////////////////////
	debug_point_instances 			: Staged_Uniform_Storage_Buffer;
	debug_mesh_instances			: Staged_Uniform_Storage_Buffer;
	debug_mesh_transforms			: Staged_Uniform_Storage_Buffer;
}

create_zscene :: (allocator: VmaAllocator, device: VkDevice) -> ZScene {
	scene : ZScene;

	scene.mesh_instances = make_staged_uniform_storage_buffer(VMA_ALLOCATOR, MESH_BUFFER_SIZE, size_of(Mesh_Instance), .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, device, "mesh_instances buffer");
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, scene.mesh_instances.staging_buffer.buffer, scene.mesh_instances.staging_buffer.allocation);
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, scene.mesh_instances.device_buffer.buffer, scene.mesh_instances.device_buffer.allocation);
	
	scene.mesh_transforms = make_staged_uniform_storage_buffer(VMA_ALLOCATOR, TRANSFORM_BUFFER_SIZE, size_of(Render_Transform), .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, device, "mesh_transforms buffer");
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, scene.mesh_transforms.staging_buffer.buffer, scene.mesh_transforms.staging_buffer.allocation);
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, scene.mesh_transforms.device_buffer.buffer, scene.mesh_transforms.device_buffer.allocation);
	
	scene.point_lights = make_staged_uniform_storage_buffer(VMA_ALLOCATOR, LIGHT_BUFFER_SIZE, size_of(Point_Light), .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, device, "point_lights buffer");
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, scene.point_lights.staging_buffer.buffer, scene.point_lights.staging_buffer.allocation);
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, scene.point_lights.device_buffer.buffer, scene.point_lights.device_buffer.allocation);

	//////////////////// DEBUG //////////////////////////////////

	scene.debug_point_instances = make_staged_uniform_storage_buffer(VMA_ALLOCATOR, SCENE_DEBUG_BUFFER_SIZE, size_of(Debug_Point), .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, device, "debug_point_instances buffer");
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, scene.debug_point_instances.staging_buffer.buffer, scene.debug_point_instances.staging_buffer.allocation);
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, scene.debug_point_instances.device_buffer.buffer, scene.debug_point_instances.device_buffer.allocation);

	scene.debug_mesh_instances = make_staged_uniform_storage_buffer(VMA_ALLOCATOR, SCENE_DEBUG_BUFFER_SIZE, size_of(Mesh_Instance), .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, device, "debug_mesh_instances buffer");
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, scene.debug_mesh_instances.staging_buffer.buffer, scene.debug_mesh_instances.staging_buffer.allocation);
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, scene.debug_mesh_instances.device_buffer.buffer, scene.debug_mesh_instances.device_buffer.allocation);

	scene.debug_mesh_transforms = make_staged_uniform_storage_buffer(VMA_ALLOCATOR, SCENE_DEBUG_BUFFER_SIZE, size_of(Render_Transform), .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, device, "debug_mesh_transforms buffer");
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, scene.debug_mesh_transforms.staging_buffer.buffer, scene.debug_mesh_transforms.staging_buffer.allocation);
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, scene.debug_mesh_transforms.device_buffer.buffer, scene.debug_mesh_transforms.device_buffer.allocation);

	/////////////////////////////////////////////////////////////
	return scene;
}

Frame_Surface_Buckets :: struct {
	Transformed_Surface	:: struct {
		constants_address	: VkDeviceAddress;
		transform_address	: VkDeviceAddress;
		surface				: *Geo_Surface;
	}
	Material_Bucket :: struct {
		material_pipeline			: VkPipeline; 
		material_pipeline_layout 	: VkPipelineLayout;
		surfaces					: [..]Transformed_Surface;
	}

	buckets		: [..]Material_Bucket;
}

// This needs optimization and camera culling
frame_generate_surface_buckets :: (zr: *ZRenderer, scene: *ZScene) {
	array_reset(*zr.frame_surfaces.buckets);
	mesh_instances := *scene.mesh_instances;
	mapped_meshes := cast,no_check(*Mesh_Instance)mesh_instances.staging_buffer.info.pMappedData;
	
	if scene.mesh_instances.count == 0
		return;

	for 0..scene.mesh_instances.count-1 {
		mesh := *mapped_meshes[it];

		// Skip if generation doesn't match
		if mesh.generation != mesh_instances.generations[it] {
			continue; 
		}

		for *surface: mesh.mesh_asset.surfaces {
			surface_material := surface.material;
			for *bucket: zr.frame_surfaces.buckets {
				if surface_material.pipeline == bucket.material_pipeline {
					transformed_surface : Frame_Surface_Buckets.Transformed_Surface;
					transformed_surface.constants_address = surface_material.constants_address;
					transformed_surface.transform_address = scene.mesh_transforms.get_device_address(*scene.mesh_transforms, mesh.transform_address);
					transformed_surface.surface = surface;
					array_add(*bucket.surfaces, transformed_surface);
					continue surface; // This will skip the array add below
				}
			}
			new_bucket : Frame_Surface_Buckets.Material_Bucket;
			new_bucket.material_pipeline = surface_material.pipeline;
			new_bucket.material_pipeline_layout = surface_material.layout;
			transformed_surface : Frame_Surface_Buckets.Transformed_Surface;
			transformed_surface.constants_address = surface_material.constants_address;
			transformed_surface.transform_address = scene.mesh_transforms.get_device_address(*scene.mesh_transforms, mesh.transform_address);
			transformed_surface.surface = surface;
			array_add(*new_bucket.surfaces, transformed_surface); 
			array_add(*zr.frame_surfaces.buckets, new_bucket);
		}
	}
}

add_scene_mesh :: (scene: *ZScene, mesh: *Mesh_Asset, local_transform: Matrix4, parent_transform: VkDeviceAddress = 0) -> VkDeviceAddress {
	mesh_render : Mesh_Instance;
	mesh_render.mesh_asset = mesh;

	render_transform : Render_Transform;
	render_transform.local_transform = local_transform;
	render_transform.parent_address = parent_transform;

	mesh_render.transform_address = scene.mesh_transforms.allocate(*scene.mesh_transforms, render_transform, *mesh_render.generation);

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
}