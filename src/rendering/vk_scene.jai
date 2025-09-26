SCENE_MESHBUFFER_SIZE :: 8*1024*1024; // 8MB
SCENE_TRANSFORMBUFFER_SIZE :: 8*1024*1024; // 8MB

ZScene :: struct {
	scene_mesh_instances	: Storage_Buffer;
	scene_transforms		: Storage_Buffer; 
}

init_zscene :: (allocator: VmaAllocator, device: VkDevice, mesh_buffer_size_override: u64, transform_buffer_size_override: u64) -> ZScene {
	scene : ZScene;
	scene.scene_mesh_instances = make_storage_buffer(VMA_ALLOCATOR, mesh_buffer_size_override, size_of(Mesh_Instance), .VK_BUFFER_USAGE_TRANSFER_SRC_BIT | .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT
																														, .VMA_MEMORY_USAGE_GPU_ONLY, device, "scene_mesh_instances buffer");
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, scene.scene_mesh_instances.buffer, scene.scene_mesh_instances.allocation);
	scene.scene_transforms = make_storage_buffer(VMA_ALLOCATOR, transform_buffer_size_override, size_of(Render_Transform), .VK_BUFFER_USAGE_TRANSFER_SRC_BIT | .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, 
																															.VMA_MEMORY_USAGE_GPU_ONLY, device, "scene_transforms buffer");
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, scene.scene_transforms.buffer, scene.scene_transforms.allocation);
	return scene;
}

Storage_Buffer :: struct {
	using base	: Allocated_Buffer;
	element_size: u32;
	capacity	: u64;
	count		: u32;
	free_list	: [..]u32;
	generations	: [..]u8;

	buffer_add :: (using self: *Storage_Buffer, value: $T, gen: *u8 = null) -> VkDeviceAddress {
		write_index : u32;
		if free_list.count > 0 {
			write_index = pop(*free_list);;
			generations[write_index] += 1;
			gen = *generations[write_index];
		}
		else {
			write_index = count;
			count += 1;
			array_resize(*generations, count);
		}

		if count >= capacity {
			panic(sprint("Attempted to allocate more transforms than capacity allows. Capacity: %", capacity));
		}

		cast_data := cast,no_check(*T)info.pMappedData;
		cast_data[write_index] = value;
		data_address := base_address + write_index * element_size;
		return data_address;
	}
	buffer_remove :: (using self: *Storage_Buffer, address: VkDeviceAddress) {
		offset := address - base_address;
		index := cast,no_check(u32)(offset / element_size);
    
		array_add(*free_list, index);
	}
}

Frame_Surface_Buckets :: struct {
	Transformed_Surface	:: struct {
		transform_address: VkDeviceAddress;
		surface: *Geo_Surface;
	}
	Material_Bucket :: struct {
		material: *Material_Instance; 
		surfaces: [..]Transformed_Surface;
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
				if surface_material == bucket.material {
					transformed_surface : Frame_Surface_Buckets.Transformed_Surface;
					transformed_surface.transform_address = mesh.transform_address;
					transformed_surface.surface = surface;
					array_add(*bucket.surfaces, transformed_surface);
					continue surface; // This will skip the array add below
				}
			}
			new_bucket : Frame_Surface_Buckets.Material_Bucket;
			new_bucket.material = surface_material;
			transformed_surface : Frame_Surface_Buckets.Transformed_Surface;
			transformed_surface.transform_address = mesh.transform_address;
			transformed_surface.surface = surface;
			array_add(*new_bucket.surfaces, transformed_surface); 
			array_add(*zr.frame_surfaces.buckets, new_bucket);
		}
	}
}

make_storage_buffer :: (allocator: VmaAllocator, alloc_size: u64, element_size: u32, usage: VkBufferUsageFlags, memory_usage: VmaMemoryUsage, device: VkDevice = null, debug_name: string = "") -> Storage_Buffer {
	new_buffer : Storage_Buffer;
	allocated_buffer := create_buffer(allocator, alloc_size, usage, memory_usage, device, debug_name);
	new_buffer.buffer = allocated_buffer.buffer;
	new_buffer.allocation = allocated_buffer.allocation;
	new_buffer.info = allocated_buffer.info;
	new_buffer.base_address = allocated_buffer.base_address;
	new_buffer.element_size = element_size;
	new_buffer.capacity = alloc_size/element_size;
	return new_buffer;
}

add_scene_mesh :: (scene: *ZScene, mesh: *Mesh_Asset, local_transform: Matrix4, parent_transform: VkDeviceAddress = 0) -> VkDeviceAddress {
	mesh_render : Mesh_Instance;
	mesh_render.mesh_asset = mesh;
	render_transform : Render_Transform;
	render_transform.local_transform = local_transform;
	render_transform.parent_address = parent_transform;

	transform_buffer := *scene.scene_transforms;
	
	mesh_render.transform_address = transform_buffer.buffer_add(transform_buffer, render_transform, *mesh_render.generation);

	return scene.scene_mesh_instances.buffer_add(*scene.scene_mesh_instances, mesh_render);
}

remove_scene_mesh :: (scene: *ZScene, address: VkDeviceAddress) {
    scene.scene_transforms.buffer_remove(*scene.scene_transforms, address);
    scene.scene_mesh_instances.buffer_remove(*scene.scene_mesh_instances, address);
}