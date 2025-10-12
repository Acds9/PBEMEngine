SCENE_MESHBUFFER_SIZE 		:: 8*1024*1024; // 8MB
SCENE_TRANSFORMBUFFER_SIZE 	:: 8*1024*1024; 
SCENE_LIGHTBUFFER_SIZE 		:: 8*1024*1024;
SCENE_LIGHTINDEXBUFFER_SIZE :: 1*1024*1024;
// TODO: these buffer sizes are all overkill

ZScene :: struct {
	scene_mesh_instances	: Uniform_Storage_Buffer;
	scene_transforms		: Uniform_Storage_Buffer; 

	scene_lights			: Uniform_Storage_Buffer;
	scene_light_indices		: Uniform_Storage_Buffer;
}

create_zscene :: (allocator: VmaAllocator, device: VkDevice, mesh_buffer_size: u64, transform_buffer_size: u64) -> ZScene {
	scene : ZScene;

	scene.scene_mesh_instances = make_uniform_storage_buffer(VMA_ALLOCATOR, mesh_buffer_size, size_of(Mesh_Instance), .VK_BUFFER_USAGE_TRANSFER_SRC_BIT | .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT
																														, .VMA_MEMORY_USAGE_CPU_TO_GPU, device, "scene_mesh_instances buffer");
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, scene.scene_mesh_instances.buffer, scene.scene_mesh_instances.allocation);
	scene.scene_transforms = make_uniform_storage_buffer(VMA_ALLOCATOR, transform_buffer_size, size_of(Render_Transform), .VK_BUFFER_USAGE_TRANSFER_SRC_BIT | .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, 
																															.VMA_MEMORY_USAGE_CPU_TO_GPU, device, "scene_transforms buffer");
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, scene.scene_transforms.buffer, scene.scene_transforms.allocation);

	scene.scene_lights = make_uniform_storage_buffer(VMA_ALLOCATOR, SCENE_LIGHTBUFFER_SIZE, size_of(Light), .VK_BUFFER_USAGE_TRANSFER_SRC_BIT | .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, 
																															.VMA_MEMORY_USAGE_CPU_TO_GPU, device, "scene_lights buffer");
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, scene.scene_lights.buffer, scene.scene_lights.allocation);

	scene.scene_light_indices = make_uniform_storage_buffer(VMA_ALLOCATOR, SCENE_LIGHTINDEXBUFFER_SIZE, size_of(u32), .VK_BUFFER_USAGE_TRANSFER_SRC_BIT | .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, 
																															.VMA_MEMORY_USAGE_CPU_TO_GPU, device, "scene_light_indices buffer");
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, scene.scene_light_indices.buffer, scene.scene_light_indices.allocation);

	return scene;
}

Frame_Surface_Buckets :: struct {
	Transformed_Surface	:: struct {
		constants_address	: VkDeviceAddress;
		transform_address	: VkDeviceAddress;
		image_index			: u32;
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
	scene_mesh_instances := *scene.scene_mesh_instances;
	mapped_meshes := cast,no_check(*Mesh_Instance)scene_mesh_instances.info.pMappedData;
	
	if scene.scene_mesh_instances.count == 0
		return;

	for 0..scene.scene_mesh_instances.count-1 {
		mesh := *mapped_meshes[it];

		// Skip if generation doesn't match
		if mesh.generation != scene_mesh_instances.generations[it] {
			continue; 
		}

		for *surface: mesh.mesh_asset.surfaces {
			surface_material := surface.material;
			for *bucket: zr.frame_surfaces.buckets {
				if surface_material.pipeline == bucket.material_pipeline {
					transformed_surface : Frame_Surface_Buckets.Transformed_Surface;
					transformed_surface.constants_address = surface_material.constants_address;
					transformed_surface.transform_address = mesh.transform_address;
					transformed_surface.image_index	= surface_material.color_texture_index;
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
			transformed_surface.transform_address = mesh.transform_address;
			transformed_surface.image_index	= surface_material.color_texture_index;
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

	transform_buffer := *scene.scene_transforms;
	
	mesh_render.transform_address = transform_buffer.allocate(transform_buffer, render_transform, *mesh_render.generation);

	return scene.scene_mesh_instances.allocate(*scene.scene_mesh_instances, mesh_render);
}

remove_scene_mesh :: (scene: *ZScene, address: VkDeviceAddress) {
    scene.scene_transforms.buffer_remove(*scene.scene_transforms, address);
    scene.scene_mesh_instances.buffer_remove(*scene.scene_mesh_instances, address);
}