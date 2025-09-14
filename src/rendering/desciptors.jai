Descriptor_Layout_Builder :: struct {
	bindings		: [..]VkDescriptorSetLayoutBinding;

	add_binding :: (using self: *Descriptor_Layout_Builder, binding: u32, type: VkDescriptorType){
		new_binding : VkDescriptorSetLayoutBinding;
		new_binding.binding = binding;
		new_binding.descriptorCount = 1;
		new_binding.descriptorType = type;
		array_add(*bindings, new_binding);
	}

	build :: (using self: *Descriptor_Layout_Builder, logical_device: VkDevice,  
								shader_stages: VkShaderStageFlags, next: *void = null, flags: VkDescriptorSetLayoutCreateFlags = 0) -> bool, string, VkDescriptorSetLayout {
		for *bindings {
			it.stageFlags |= shader_stages;
		}
	
		info : VkDescriptorSetLayoutCreateInfo;
		info.sType = .VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
		info.pNext = next;

		info.pBindings = bindings.data;
		info.bindingCount = xx bindings.count;
		info.flags = flags;

		set : VkDescriptorSetLayout;
		result := vkCreateDescriptorSetLayout(logical_device, *info, null, *set);
		if result != .VK_SUCCESS {
			return false, sprint("%\n", result), set;
		}
		return true, "", set;
	}
}

init_descriptors :: (zr: *ZRenderer) -> bool, string {
	// Pool holds 10 sets, 1 image each
	sizes : [..]Descriptor_Pool_Size_Ratio;
	array_add(*sizes, .{.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, 1});

	global_descriptor_allocator := *zr.global_desc_allocator;
	global_descriptor_allocator.init(global_descriptor_allocator, zr.logical_device, 10, sizes);

	draw_image_builder : Descriptor_Layout_Builder;
	draw_image_builder.add_binding(*draw_image_builder, 0, .VK_DESCRIPTOR_TYPE_STORAGE_IMAGE);
	_, _, zr.draw_image_desc_layout = draw_image_builder.build(*draw_image_builder, zr.logical_device, .VK_SHADER_STAGE_COMPUTE_BIT);
	
	zr.draw_image_descriptors = global_descriptor_allocator.allocate(global_descriptor_allocator, zr.logical_device, zr.draw_image_desc_layout);

	writer : Descriptor_Writer;
	writer.write_image(*writer, 0, zr.draw_image.image_view, VK_NULL_HANDLE, .VK_IMAGE_LAYOUT_GENERAL, .VK_DESCRIPTOR_TYPE_STORAGE_IMAGE);
	writer.update_set(*writer, zr.logical_device, zr.draw_image_descriptors);

	array_add(*zr.deletion_queue.desc_allocators, .{zr.logical_device, *zr.global_desc_allocator});
	array_add(*zr.deletion_queue.desc_layouts, .{zr.logical_device, zr.draw_image_desc_layout});

	gpu_data_builder : Descriptor_Layout_Builder;
	gpu_data_builder.add_binding(*gpu_data_builder, 0, .VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER);
	_, _, zr.gpu_scene_data_desc_layout = gpu_data_builder.build(*gpu_data_builder, zr.logical_device, .VK_SHADER_STAGE_VERTEX_BIT | .VK_SHADER_STAGE_FRAGMENT_BIT);
	
	array_add(*zr.deletion_queue.desc_layouts, .{zr.logical_device, zr.gpu_scene_data_desc_layout});
	
	for 0..MAX_FRAMES_IN_FLIGHT-1 {
		frame_sizes : [4]Descriptor_Pool_Size_Ratio = .[
			.{.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, 3},
			.{.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, 3}, 
			.{.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, 3}, 
			.{.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 4}
		];
		descriptors := *zr.frame_data[it].frame_descriptors;
		descriptors.init(descriptors, zr.logical_device, 1000, frame_sizes); 
	}

	image_builder : Descriptor_Layout_Builder;
	image_builder.add_binding(*image_builder, 0, .VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER);
	_, _, zr.image_descriptor_layout = image_builder.build(*image_builder, zr.logical_device, .VK_SHADER_STAGE_FRAGMENT_BIT);
	array_add(*zr.deletion_queue.desc_layouts, .{zr.logical_device, zr.image_descriptor_layout});
	
	return true, "";
}

Descriptor_Pool_Size_Ratio :: struct {
	type : VkDescriptorType;
	ratio : float;
}

Descriptor_Allocator :: struct {

	init :: (using self: *Descriptor_Allocator, logical_device: VkDevice, max_sets: u32, pool_ratios: []Descriptor_Pool_Size_Ratio) {
		array_reset(*ratios);

		for ratio: pool_ratios {
			array_add(*ratios, ratio);
		}

		new_pool : VkDescriptorPool = create_pool(self, logical_device, max_sets, pool_ratios);
		sets_per_pool = cast,no_check(u32)(max_sets * 1.5);
		array_add(*ready_pools, new_pool);
	}

	clear_pools :: (using self: *Descriptor_Allocator, logical_device: VkDevice) {
		for ready_pools {
			vkResetDescriptorPool(logical_device, it, 0);
		}
		for full_pools {
			vkResetDescriptorPool(logical_device, it, 0);
			array_add(*ready_pools, it);
		}
		array_reset(*full_pools);
	}

	destroy_pools :: (using self: *Descriptor_Allocator, logical_device: VkDevice) {
		for ready_pools {
			vkDestroyDescriptorPool(logical_device, it, null);
		}
		array_reset(*ready_pools);
		for full_pools {
			vkDestroyDescriptorPool(logical_device, it, null);
		}
		array_reset(*full_pools);
	}

	allocate :: (using self: *Descriptor_Allocator, logical_device: VkDevice, layout: VkDescriptorSetLayout, next: *void = null) -> VkDescriptorSet {
		pool_to_use : VkDescriptorPool = get_pool(self, logical_device);

		alloc_info : VkDescriptorSetAllocateInfo;
		alloc_info.pNext = next;
		alloc_info.sType = .VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO;
		alloc_info.descriptorPool = pool_to_use;
		alloc_info.descriptorSetCount = 1;
		alloc_info.pSetLayouts = *layout;

		descriptor_set : VkDescriptorSet;
		result : VkResult = vkAllocateDescriptorSets(logical_device, *alloc_info, *descriptor_set);

		if result == .VK_ERROR_OUT_OF_POOL_MEMORY || result == .VK_ERROR_FRAGMENTED_POOL {
			array_add(*full_pools, pool_to_use);

			pool_to_use = get_pool(self, logical_device);
			alloc_info.descriptorPool = pool_to_use;

			result = vkAllocateDescriptorSets(logical_device, *alloc_info, *descriptor_set);
			if result != .VK_SUCCESS {
				panic("Could not find a pool to allocate into\n");
			}
		}
		array_add(*ready_pools, pool_to_use);
		return descriptor_set;
	}

	get_pool :: (using self: *Descriptor_Allocator, logical_device: VkDevice) -> VkDescriptorPool {
		new_pool : VkDescriptorPool;
		if ready_pools.count != 0 {
			new_pool = pop(*ready_pools); // Pop it so other threads can't work with it
		}
		else {
			new_pool = create_pool(self, logical_device, sets_per_pool, ratios);
			sets_per_pool = cast,no_check(u32)(sets_per_pool * 1.5);
			if sets_per_pool > 4092 {
				sets_per_pool = 4092;
			}
		}
		return new_pool;
	}

	create_pool :: (using self: *Descriptor_Allocator, logical_device: VkDevice, set_count: u32, pool_ratios: []Descriptor_Pool_Size_Ratio) -> VkDescriptorPool {
		pool_sizes : [..]VkDescriptorPoolSize;
		for ratio: pool_ratios {
			descriptor_pool_size : VkDescriptorPoolSize;
			descriptor_pool_size.type = ratio.type;
			descriptor_pool_size.descriptorCount = cast,no_check(u32)(ratio.ratio * set_count);
			array_add(*pool_sizes, descriptor_pool_size);
		}

		pool_info : VkDescriptorPoolCreateInfo;
		pool_info.sType = .VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO;
		pool_info.maxSets = set_count;
		pool_info.poolSizeCount = cast,no_check(u32)pool_sizes.count;
		pool_info.pPoolSizes = pool_sizes.data;

		new_pool : VkDescriptorPool;
		vkCreateDescriptorPool(logical_device, *pool_info, null, *new_pool);
		return new_pool;
	}

	ratios			: [..]Descriptor_Pool_Size_Ratio;
	full_pools		: [..]VkDescriptorPool;
	ready_pools		: [..]VkDescriptorPool;
	sets_per_pool	: u32;
}

Descriptor_Writer :: struct {
	image_infos  	: [..]VkDescriptorImageInfo;
	buffer_infos 	: [..]VkDescriptorBufferInfo;
	writes			: [..]VkWriteDescriptorSet;

	write_image :: (using self: *Descriptor_Writer, binding: u32, image: VkImageView, sampler: VkSampler, layout: VkImageLayout, type: VkDescriptorType) {
		info : VkDescriptorImageInfo;
		info.sampler = sampler;
		info.imageView = image;
		info.imageLayout = layout;
		array_add(*image_infos, info);
		
		write : VkWriteDescriptorSet;
		write.sType = .VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
		write.dstBinding = binding;
		write.dstSet = VK_NULL_HANDLE;
		write.descriptorCount = 1;
		write.descriptorType = type;
		write.pImageInfo = *image_infos[image_infos.count-1];

		array_add(*writes, write);
	}

	write_buffer :: (using self: *Descriptor_Writer, binding: u32, buffer: VkBuffer, size: u64, offset: u64, type: VkDescriptorType) {
		info : VkDescriptorBufferInfo;
		info.buffer = buffer;
		info.offset = offset;
		info.range = size;
		array_add(*buffer_infos, info);
		
		write : VkWriteDescriptorSet;
		write.sType = .VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
		write.dstBinding = binding;
		write.dstSet = VK_NULL_HANDLE; // Left empty for now until we need to write it
		write.descriptorCount = 1;
		write.descriptorType = type;
		write.pBufferInfo = *buffer_infos[buffer_infos.count-1];
		array_add(*writes, write);
	}

	clear :: (using self: *Descriptor_Writer) {
		array_reset(*image_infos);
		array_reset(*writes);
		array_reset(*buffer_infos);
	}

	update_set :: (using self: *Descriptor_Writer, logical_device: VkDevice, set: VkDescriptorSet) {
		for *writes {
			it.dstSet = set;
		}

		vkUpdateDescriptorSets(logical_device, cast,no_check(u32) writes.count, writes.data, 0, null);
	}
}