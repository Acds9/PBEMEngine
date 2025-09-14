#import "Basic";
#import "Math"; 

create_render_pass :: (zr: *ZRenderer) -> bool, string {
    color_attachment_desc := vkinit_attachment_description(
        zr.swapchain_image_format,
        .VK_SAMPLE_COUNT_1_BIT,
        .VK_ATTACHMENT_LOAD_OP_CLEAR,
        .VK_ATTACHMENT_STORE_OP_STORE,
        .VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        .VK_ATTACHMENT_STORE_OP_DONT_CARE,
        .VK_IMAGE_LAYOUT_UNDEFINED,
        .VK_IMAGE_LAYOUT_PRESENT_SRC_KHR
    );
    
    color_attachment_ref := vkinit_attachment_reference(0, .VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL);
    
    subpass := vkinit_subpass_description(.VK_PIPELINE_BIND_POINT_GRAPHICS, color_attachment_count = 1, color_attachments = *color_attachment_ref);
    
    dependency := vkinit_subpass_dependency(
        VK_SUBPASS_EXTERNAL, 0, .VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        .VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT, 0, .VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT
	);
    
    render_pass_create_info := vkinit_render_pass_create_info(
        1, *color_attachment_desc,
        1, *subpass,
        1, *dependency
    );
    
    result := vkCreateRenderPass(zr.logical_device, *render_pass_create_info, null, *zr.render_pass);
    if result != .VK_SUCCESS
        return false, "ERROR: Failed to create Render Pass";
    return true, "";
}

create_shader_module :: (zr: *ZRenderer, file_path: string) -> bool, VkShaderModule {
	shader_code_string := read_entire_file(file_path);
    shader_code := string_to_byte_array(shader_code_string);
    success, shader_module := create_shader_module(zr, shader_code);
	return success, shader_module;
}

create_shader_module :: (zr: *ZRenderer, code: [..]u8) -> bool, VkShaderModule {
	create_info : VkShaderModuleCreateInfo;
	create_info.sType = .VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
	create_info.codeSize = xx code.count;
	create_info.pCode = xx code.data;

	shader_module : VkShaderModule;
	result := vkCreateShaderModule(zr.logical_device, *create_info, null, *shader_module);
	if result != .VK_SUCCESS 
		return false, null;
	return true, shader_module;
}

create_framebuffers :: (zr: *ZRenderer) -> bool, string {
    array_resize(*zr.swapchain_framebuffers, zr.swapchain_imageviews.count);
    for zr.swapchain_imageviews {
        attachments : [..]VkImageView;
        array_add(*attachments, zr.swapchain_imageviews[it_index]);
        
        framebuffer_create_info := vkinit_framebuffer_create_info(
            zr.render_pass, 1, attachments.data, zr.swapchain_extent.width, zr.swapchain_extent.height
        );
        
        result := vkCreateFramebuffer(zr.logical_device, *framebuffer_create_info, null, *zr.swapchain_framebuffers[it_index]);
        if result != .VK_SUCCESS
            return false, sprint("%\n", result);
    }
    return true, "";
}

init_commands :: (zr: *ZRenderer) -> bool, string {
	queue_family_indices := zr.queue_indices;

	pool_info : VkCommandPoolCreateInfo ;
	pool_info.sType = .VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
	pool_info.flags = .VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
	pool_info.queueFamilyIndex = xx queue_family_indices.graphics;

	for zr.frame_data {
		// Create cpmmand pool first
		result := vkCreateCommandPool(zr.logical_device, *pool_info, null, *it.command_pool);
		if result != .VK_SUCCESS 
			return false, sprint("%\n", result);

		// Now allocate the buffer
		alloc_info : VkCommandBufferAllocateInfo;
		alloc_info.sType = .VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
		alloc_info.commandPool = it.command_pool;
		alloc_info.level = .VK_COMMAND_BUFFER_LEVEL_PRIMARY;
		alloc_info.commandBufferCount = 1; // Just one tied to this pool, but we have multiple pools
		
		result = vkAllocateCommandBuffers(zr.logical_device, *alloc_info, *it.command_buffer);
		if result != .VK_SUCCESS 
			return false, sprint("%\n", result);
	}

	immediate_result := vkCreateCommandPool(zr.logical_device, *pool_info, null, *zr.immediate_command_pool);
	if immediate_result != .VK_SUCCESS 
			return false, sprint("%\n", immediate_result);
			
	command_buffer_alloc_info : VkCommandBufferAllocateInfo;
	command_buffer_alloc_info.sType = .VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
	command_buffer_alloc_info.commandPool = zr.immediate_command_pool;
	command_buffer_alloc_info.level = .VK_COMMAND_BUFFER_LEVEL_PRIMARY;
	command_buffer_alloc_info.commandBufferCount = 1; 

	immediate_result = vkAllocateCommandBuffers(zr.logical_device, *command_buffer_alloc_info, *zr.immediate_command_buffer);
	if immediate_result != .VK_SUCCESS 
			return false, sprint("%\n", immediate_result);

	array_add(*zr.deletion_queue.command_pools, .{zr.logical_device, zr.immediate_command_pool});

	return true, "";
}
 
// This should NOT be here
draw_gradient_background :: (zr: *ZRenderer, command_buffer: VkCommandBuffer) {
	// Bind the gradient drawing compute pipeline
	vkCmdBindPipeline(command_buffer, .VK_PIPELINE_BIND_POINT_COMPUTE, zr.gradient_pipeline);

	// bind the descriptor set containing the draw image for the compute pipeline
	vkCmdBindDescriptorSets(command_buffer, .VK_PIPELINE_BIND_POINT_COMPUTE, zr.gradient_pipeline_layout, 0, 1, *zr.draw_image_descriptors, 0, null);

	// execute the compute pipeline dispatch. We are using 16x16 workgroup size so we need to divide by it
	vkCmdDispatch(command_buffer, cast,no_check(u32) ceil(zr.draw_extent.width / 16.0), cast,no_check(u32) ceil(zr.draw_extent.height / 16.0), 1);
}

create_sync_objects :: (zr: *ZRenderer) -> bool, string {
	semaphore_create_info : VkSemaphoreCreateInfo;
	semaphore_create_info.sType = .VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;

	fence_create_info : VkFenceCreateInfo;
	fence_create_info.sType = .VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
	fence_create_info.flags = .VK_FENCE_CREATE_SIGNALED_BIT;

	for zr.frame_data {
		result := vkCreateSemaphore(zr.logical_device, *semaphore_create_info, null, *it.swapchain_semaphore);
		if result != .VK_SUCCESS 
			return false, sprint("%\n", result);
		result = vkCreateSemaphore(zr.logical_device, *semaphore_create_info, null, *it.render_semaphore);
		if result != .VK_SUCCESS 
			return false, sprint("%\n", result);

		result = vkCreateFence(zr.logical_device, *fence_create_info, null, *it.render_fence);
		if result != .VK_SUCCESS 
			return false, sprint("%\n", result);
	}

	result := vkCreateFence(zr.logical_device, *fence_create_info, null, *zr.immediate_fence);
	if result != .VK_SUCCESS 
		return false, sprint("%\n", result);

	array_add(*zr.deletion_queue.fences, .{zr.logical_device, zr.immediate_fence});
	return true, "";
}

create_buffer :: (zr: *ZRenderer, alloc_size: u64, usage: VkBufferUsageFlags, memory_usage: VmaMemoryUsage, debug_name: string = "") -> Allocated_Buffer {
	buffer_info : VkBufferCreateInfo;
	buffer_info.sType = .VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
	buffer_info.size = alloc_size;

	buffer_info.usage = usage;

	vma_alloc_info : VmaAllocationCreateInfo;
	vma_alloc_info.usage = memory_usage;
	vma_alloc_info.flags = .VMA_ALLOCATION_CREATE_MAPPED_BIT;
	
	new_buffer : Allocated_Buffer;
	result := vmaCreateBuffer(zr.allocator, *buffer_info, *vma_alloc_info, *new_buffer.buffer, *new_buffer.allocation, *new_buffer.info);
	if result != .VK_SUCCESS {
		print("ERROR: could not create memory buffer\n");
		debug_break();
	}
	if ENABLE_VALIDATION_LAYERS {
		if debug_name == "" {
			panic("ERROR: vk_debug_name not set for buffer in debug\n");
		}
		set_vk_object_name(zr.logical_device, .BUFFER, cast(u64)new_buffer.buffer, debug_name);
	}
	return new_buffer;
}

destroy_buffer :: (allocator: VmaAllocator, buffer: *Allocated_Buffer) {
	vmaDestroyBuffer(allocator, buffer.buffer, buffer.allocation);
}

init_default_data :: (zr: *ZRenderer) {
	zr.white_image = create_image(zr, *COLOR_WHITE, .{1,1,1}, .VK_FORMAT_R8G8B8A8_UNORM, .VK_IMAGE_USAGE_SAMPLED_BIT, false, "Image_White");
	array_add(*zr.deletion_queue.images, .{zr.allocator, zr.white_image.image, zr.white_image.allocation});
	array_add(*zr.deletion_queue.image_views, .{zr.logical_device, zr.white_image.image_view});

	zr.grey_image = create_image(zr, *COLOR_GREY, .{1,1,1}, .VK_FORMAT_R8G8B8A8_UNORM, .VK_IMAGE_USAGE_SAMPLED_BIT, false, "Image_Grey");
	array_add(*zr.deletion_queue.images, .{zr.allocator, zr.grey_image.image, zr.grey_image.allocation});
	array_add(*zr.deletion_queue.image_views, .{zr.logical_device, zr.grey_image.image_view});

	zr.black_image = create_image(zr, *COLOR_BLACK, .{1,1,1}, .VK_FORMAT_R8G8B8A8_UNORM, .VK_IMAGE_USAGE_SAMPLED_BIT, false, "Image_Black");
	array_add(*zr.deletion_queue.images, .{zr.allocator, zr.black_image.image, zr.black_image.allocation});
	array_add(*zr.deletion_queue.image_views, .{zr.logical_device, zr.black_image.image_view});

	pixels : [16*16]Color;
	x, y : u32;
	for *pixels {  
		x_block := x / 2;
		y_block := y / 2;
    
		if (x_block + y_block) % 2 == 0 {
			<<it = COLOR_BLACK;
		} else {
			<<it = COLOR_MAGENTA;
		}
    
		x += 1;
		if x == 16 {
			y += 1;
			x = 0;
		}
	}
	
	zr.error_checkerboard = create_image(zr, pixels.data, .{16,16,1}, .VK_FORMAT_R8G8B8A8_UNORM, .VK_IMAGE_USAGE_SAMPLED_BIT, false, "Image_Error");
	array_add(*zr.deletion_queue.images, .{zr.allocator, zr.error_checkerboard.image, zr.error_checkerboard.allocation});
	array_add(*zr.deletion_queue.image_views, .{zr.logical_device, zr.error_checkerboard.image_view});

	sampler_info : VkSamplerCreateInfo;
	sampler_info.sType = .VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO;

	sampler_info.magFilter = .VK_FILTER_NEAREST;
	sampler_info.minFilter = .VK_FILTER_NEAREST;

	sampler_info.addressModeU = .VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
	sampler_info.addressModeV = .VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
	sampler_info.addressModeW = .VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
	sampler_info.mipLodBias = 0.0;
	sampler_info.anisotropyEnable = VK_FALSE;
	sampler_info.maxAnisotropy = 1.0;
	sampler_info.compareEnable = VK_FALSE;
	sampler_info.compareOp = .VK_COMPARE_OP_ALWAYS;
	sampler_info.minLod = 0.0;
	sampler_info.maxLod = 0.0;
	sampler_info.borderColor = .VK_BORDER_COLOR_INT_OPAQUE_BLACK;
	sampler_info.unnormalizedCoordinates = VK_FALSE;

	vkCreateSampler(zr.logical_device, *sampler_info, null, *zr.default_sampler_nearest);

	sampler_info.magFilter = .VK_FILTER_LINEAR;
	sampler_info.minFilter = .VK_FILTER_LINEAR;
	vkCreateSampler(zr.logical_device, *sampler_info, null, *zr.default_sampler_linear);

	array_add(*zr.deletion_queue.samplers, .{zr.logical_device, zr.default_sampler_nearest});
	array_add(*zr.deletion_queue.samplers, .{zr.logical_device, zr.default_sampler_linear});
}

set_vk_object_name :: (logical_device: VkDevice, object_type: VkObjectType, handle: u64, name: string) {
 	if !vkSetDebugUtilsObjectNameEXT {
		print("Object Name Debug EXT not loaded\n");
		return;
	}
    
    name_info: VkDebugUtilsObjectNameInfoEXT;
    name_info.sType = .VK_STRUCTURE_TYPE_DEBUG_UTILS_OBJECT_NAME_INFO_EXT;
    name_info.objectType = object_type;
    name_info.objectHandle = handle;
    name_info.pObjectName = name.data;
    
    vkSetDebugUtilsObjectNameEXT(logical_device, *name_info);
}

create_image :: (zr: *ZRenderer, size: VkExtent3D, format: VkFormat, usage: VkImageUsageFlags, mip_mapped: bool = false, name: string = "") -> Allocated_Image {
	if(ENABLE_VALIDATION_LAYERS && name == "") {
		panic_no_name("image");
	}

	new_image : Allocated_Image;
	new_image.image_format = format;
	new_image.image_extent = size;

	image_info := vkinit_image_create_info(format, usage, size);
	if mip_mapped {
		image_info.mipLevels = get_mip_levels(size.width, size.height);
	}

	// Allocate on GPU memory always-ish
	allocation_info : VmaAllocationCreateInfo;
	allocation_info.usage = .VMA_MEMORY_USAGE_GPU_ONLY;
	allocation_info.requiredFlags = .VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT;

	// Allocate and create
	result := vmaCreateImage(zr.allocator, *image_info, *allocation_info, *new_image.image, *new_image.allocation, null);
	if result != .VK_SUCCESS {
		panic(sprint("VK ERROR: Could not create image, %", result));
	}
	if(ENABLE_VALIDATION_LAYERS) {
		set_vk_object_name(zr.logical_device, .IMAGE, cast(u64)new_image.image, name);
	}

	// Set correct aspect in case its depth image
	aspect_flag : VkImageAspectFlags = .VK_IMAGE_ASPECT_COLOR_BIT;
	if format == .VK_FORMAT_D32_SFLOAT {
		aspect_flag = .VK_IMAGE_ASPECT_DEPTH_BIT;
	}

	// Make image view
	view_info : VkImageViewCreateInfo = vkinit_imageview_create_info(format, new_image.image, aspect_flag);
	view_info.subresourceRange.levelCount = image_info.mipLevels;
	
	result = vkCreateImageView(zr.logical_device, *view_info, null, *new_image.image_view);
	if result != .VK_SUCCESS {
		panic(sprint("VK ERROR: Could not create imageview, %", result));
	}

	if(ENABLE_VALIDATION_LAYERS) {
		set_vk_object_name(zr.logical_device, .IMAGE_VIEW, cast(u64)new_image.image_view, sprint("%_View", name));
	}

	return new_image;
}

create_image :: (zr: *ZRenderer, data: *void, size: VkExtent3D, format: VkFormat, usage: VkImageUsageFlags, mip_mapped : bool= false, name: string = "") -> Allocated_Image {
	data_size := size.width * size.height * size.depth * 4;
	upload_buffer : Allocated_Buffer = create_buffer(zr, data_size, .VK_BUFFER_USAGE_TRANSFER_SRC_BIT, .VMA_MEMORY_USAGE_CPU_TO_GPU, "Temp Buffer");

	memcpy(upload_buffer.info.pMappedData, data, data_size);

	new_image : Allocated_Image = create_image(zr, size, format, usage | .VK_IMAGE_USAGE_TRANSFER_DST_BIT | .VK_IMAGE_USAGE_TRANSFER_SRC_BIT, mip_mapped, name);

	immediate_submit(zr, #code {
		vkutil_transition_image(cmd, new_image.image, .VK_IMAGE_LAYOUT_UNDEFINED, .VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, .VK_IMAGE_ASPECT_COLOR_BIT);

		copy_region : VkBufferImageCopy;
		copy_region.bufferOffset = 0;
		copy_region.bufferRowLength = 0;
		copy_region.bufferImageHeight = 0;
		copy_region.imageOffset = .{0, 0, 0};

		copy_region.imageSubresource.aspectMask = .VK_IMAGE_ASPECT_COLOR_BIT;
		copy_region.imageSubresource.mipLevel = 0;
		copy_region.imageSubresource.baseArrayLayer = 0;
		copy_region.imageSubresource.layerCount = 1;
		copy_region.imageExtent = size;

		// copy the buffer into the image
		vkCmdCopyBufferToImage(cmd, upload_buffer.buffer, new_image.image, .VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, *copy_region);

		vkutil_transition_image(cmd, new_image.image, .VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, .VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL, .VK_IMAGE_ASPECT_COLOR_BIT);
	});

	destroy_buffer(zr.allocator, *upload_buffer);

	return new_image;
}

destroy_image :: (image: Allocated_Image) {
	
}