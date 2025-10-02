DESCRIPTOR_BUFFER_SIZE :: 1*1024*1024; // 1MB
MAX_TEXTURES :: 1024;
MAX_SAMPLERS :: 4;

init_descriptor_buffers :: (zr: *ZRenderer) {
	zr.descriptor_buffer_properties.sType = .VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DESCRIPTOR_BUFFER_PROPERTIES_EXT;
	props2: VkPhysicalDeviceProperties2;
    props2.sType = .VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2;
    props2.pNext = *zr.descriptor_buffer_properties;  // Chain because Vulkan bs
    vkGetPhysicalDeviceProperties2(zr.physical_device, *props2);

	zr.descriptor_writer.device = zr.device;
	zr.descriptor_writer.offset_alignement = zr.descriptor_buffer_properties.descriptorBufferOffsetAlignment;

	image_descriptor_size := zr.descriptor_buffer_properties.sampledImageDescriptorSize;  // e.g., 32 bytes
	image_buffer_size := MAX_TEXTURES * image_descriptor_size;

	aligned_size := align_up(DESCRIPTOR_BUFFER_SIZE, zr.descriptor_buffer_properties.descriptorBufferOffsetAlignment);
	zr.image_descriptor_buffer = make_linear_buffer(VMA_ALLOCATOR, xx image_buffer_size, xx image_descriptor_size, .VK_BUFFER_USAGE_RESOURCE_DESCRIPTOR_BUFFER_BIT_EXT | .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT,
																								.VMA_MEMORY_USAGE_CPU_TO_GPU, zr.device, sprint("Image Descriptor Buffer"));
	zr.image_descriptor_buffer.element_size = zr.descriptor_buffer_properties.combinedImageSamplerDescriptorSize;
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, *zr.image_descriptor_buffer);

	sampler_descriptor_size := zr.descriptor_buffer_properties.samplerDescriptorSize;
	sampler_buffer_size := 64*MAX_SAMPLERS;
	zr.sampler_descriptor_buffer = make_linear_buffer(VMA_ALLOCATOR, xx sampler_buffer_size, xx sampler_descriptor_size, .VK_BUFFER_USAGE_RESOURCE_DESCRIPTOR_BUFFER_BIT_EXT | .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT,
																								.VMA_MEMORY_USAGE_CPU_TO_GPU, zr.device, "Sampler Descriptor Buffer");
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, *zr.sampler_descriptor_buffer);

	
}

create_descriptor_set_layout :: (device: VkDevice, bindings: []VkDescriptorSetLayoutBinding, flags: VkDescriptorSetLayoutCreateFlags = 0) -> VkDescriptorSetLayout {
    info : VkDescriptorSetLayoutCreateInfo;
    info.sType = .VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
    info.pBindings = bindings.data;
    info.bindingCount = xx bindings.count;
    info.flags = flags | .VK_DESCRIPTOR_SET_LAYOUT_CREATE_DESCRIPTOR_BUFFER_BIT_EXT;  // CRITICAL!
    
    layout : VkDescriptorSetLayout;
    result := vkCreateDescriptorSetLayout(device, *info, null, *layout);
    if result != .VK_SUCCESS {
        panic(sprint("Failed to create descriptor set layout: %", result));
    }
    return layout;
}

init_descriptor_layouts :: (zr: *ZRenderer) {
    // Image descriptor layout
    image_binding := VkDescriptorSetLayoutBinding.{
        binding = 0,
        descriptorType = .VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE,
        descriptorCount = MAX_TEXTURES,
        stageFlags = .VK_SHADER_STAGE_FRAGMENT_BIT,
    };
    
    image_layout_info : VkDescriptorSetLayoutCreateInfo;
    image_layout_info.sType = .VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
    image_layout_info.bindingCount = 1;
    image_layout_info.pBindings = *image_binding;
    image_layout_info.flags = .VK_DESCRIPTOR_SET_LAYOUT_CREATE_DESCRIPTOR_BUFFER_BIT_EXT; 
    
    vkCreateDescriptorSetLayout(zr.device, *image_layout_info, null, *zr.image_array_layout);
	set_vk_object_name(zr.device, .DESCRIPTOR_SET_LAYOUT, cast(u64)zr.image_array_layout, "image_array_layout Descriptor Set Layout");
	queue_deletion(*GLOBAL_DELETION_QUEUE, zr.device, zr.image_array_layout);


	// Image sampler  layout
    sampler_binding := VkDescriptorSetLayoutBinding.{
        binding = 0,
        descriptorType = .VK_DESCRIPTOR_TYPE_SAMPLER,
        descriptorCount = MAX_SAMPLERS,
        stageFlags = .VK_SHADER_STAGE_FRAGMENT_BIT,
    };
    
    sampler_layout_info : VkDescriptorSetLayoutCreateInfo;
    sampler_layout_info.sType = .VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
    sampler_layout_info.bindingCount = 1;
    sampler_layout_info.pBindings = *sampler_binding;
    sampler_layout_info.flags = .VK_DESCRIPTOR_SET_LAYOUT_CREATE_DESCRIPTOR_BUFFER_BIT_EXT;
    
    vkCreateDescriptorSetLayout(zr.device, *sampler_layout_info, null, *zr.sampler_array_layout);
	set_vk_object_name(zr.device, .DESCRIPTOR_SET_LAYOUT, cast(u64)zr.sampler_array_layout, "sampler_array_layout Descriptor Set Layout");
	queue_deletion(*GLOBAL_DELETION_QUEUE, zr.device, zr.sampler_array_layout);
}

Descriptor_Buffer_Writer :: struct {
    device 				: VkDevice;
	offset_alignement 	: u64; 
    
    write_image :: (using self: *Descriptor_Buffer_Writer, buffer: *Linear_Buffer, image_view: VkImageView, layout: VkImageLayout) -> u64 {
		binding_offset := buffer.allocate_descriptor(buffer, offset_alignement);

        image_info : VkDescriptorImageInfo;
		image_info.sampler = null;
		image_info.imageView = image_view;
		image_info.imageLayout = layout;
        
        descriptor_info : VkDescriptorGetInfoEXT;
		descriptor_info.sType = .VK_STRUCTURE_TYPE_DESCRIPTOR_GET_INFO_EXT;
		descriptor_info.type = .VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE;
		descriptor_info.data = .{pSampledImage  = *image_info};
        
        write_address := cast,no_check(*u8)buffer.info.pMappedData + (binding_offset * buffer.element_size);
        vkGetDescriptorEXT(device, *descriptor_info, buffer.element_size, write_address);
		return binding_offset;
    }
    
    write_sampler :: (using self: *Descriptor_Buffer_Writer, buffer: *Linear_Buffer, sampler: VkSampler) -> u64 {
		binding_offset := buffer.allocate_descriptor(buffer, offset_alignement);

        descriptor_info : VkDescriptorGetInfoEXT;
        descriptor_info.sType = .VK_STRUCTURE_TYPE_DESCRIPTOR_GET_INFO_EXT;
        descriptor_info.type = .VK_DESCRIPTOR_TYPE_SAMPLER;
        descriptor_info.data = .{pSampler = *sampler};
        
        write_ptr := cast(*u8)buffer.info.pMappedData + (binding_offset * buffer.element_size);
        vkGetDescriptorEXT(device, *descriptor_info, buffer.element_size, write_ptr);
		return binding_offset;
    }
}