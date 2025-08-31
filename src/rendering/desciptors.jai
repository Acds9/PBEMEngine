Descriptor_Layout_Builder :: struct {
	bindings		: [..]VkDescriptorSetLayoutBinding;
}

add_binding :: (builder: *Descriptor_Layout_Builder, binding: u32, type: VkDescriptorType){
	new_binding : VkDescriptorSetLayoutBinding;
	new_binding.binding = binding;
	new_binding.descriptorCount = 1;
	new_binding.descriptorType = type;
	array_add(*builder.bindings, new_binding);
}

build_descriptor_set_layout :: (builder: *Descriptor_Layout_Builder, logical_device: VkDevice,  
								shader_stages: VkShaderStageFlags, next: *void = null, flags: VkDescriptorSetLayoutCreateFlags = 0) -> bool, string, VkDescriptorSetLayout {
	for *builder.bindings {
		it.stageFlags |= shader_stages;
	}
	
	info : VkDescriptorSetLayoutCreateInfo;
	info.sType = .VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
	info.pNext = next;

	info.pBindings = builder.bindings.data;
	info.bindingCount = xx builder.bindings.count;
	info.flags = flags;

	set : VkDescriptorSetLayout;
	result := vkCreateDescriptorSetLayout(logical_device, *info, null, *set);
	if result != .VK_SUCCESS {
		return false, sprint("%\n", result), set;
	}
	return true, "", set;
}

Desc_Pool_Size_Ratio :: struct {
	type : VkDescriptorType;
	ratio : float;
}

Descriptor_Allocator :: struct {
	pool : VkDescriptorPool;
}

init_descriptor_pool :: (allocator: *Descriptor_Allocator, logical_device: VkDevice, max_sets: u32, pool_ratios: []Desc_Pool_Size_Ratio) {
	pool_sizes : [..]VkDescriptorPoolSize;
	for pool_ratios {
		pool_size : VkDescriptorPoolSize;
		pool_size.type = it.type;
		pool_size.descriptorCount = xx it.ratio * max_sets;
		array_add(*pool_sizes, pool_size);
	}

	pool_info : VkDescriptorPoolCreateInfo;
	pool_info.sType = .VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO;
	pool_info.flags = 0;
	pool_info.maxSets = max_sets;
	pool_info.poolSizeCount = xx pool_sizes.count;
	pool_info.pPoolSizes = pool_sizes.data;

	vkCreateDescriptorPool(logical_device, *pool_info, null, *allocator.pool);
}

allocate_descriptor_set :: (allocator: *Descriptor_Allocator, logical_device: VkDevice, layout: VkDescriptorSetLayout) -> VkDescriptorSet {
	alloc_info : VkDescriptorSetAllocateInfo;
	alloc_info.sType = .VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO;
	alloc_info.descriptorPool = allocator.pool;
	alloc_info.descriptorSetCount = 1;
	alloc_info.pSetLayouts = *layout;

	descriptor_set : VkDescriptorSet;
	vkAllocateDescriptorSets(logical_device, *alloc_info, *descriptor_set);
	return descriptor_set;
}