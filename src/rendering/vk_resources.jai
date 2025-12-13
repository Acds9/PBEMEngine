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
    
    result := vkCreateRenderPass(zr.device, *render_pass_create_info, null, *zr.render_pass);
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
	result := vkCreateShaderModule(zr.device, *create_info, null, *shader_module);
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
        
        result := vkCreateFramebuffer(zr.device, *framebuffer_create_info, null, *zr.swapchain_framebuffers[it_index]);
        if result != .VK_SUCCESS
            return false, sprint("%\n", result);
    }
    return true, "";
}

init_commands :: (zr: *ZRenderer) -> bool, string {
	pool_info : VkCommandPoolCreateInfo ;
	pool_info.sType = .VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
	pool_info.flags = .VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
	pool_info.queueFamilyIndex = xx zr.queue_indices.graphics;

	immediate_result := vkCreateCommandPool(zr.device, *pool_info, null, *zr.immediate_command_pool);
	if immediate_result != .VK_SUCCESS 
			return false, sprint("%\n", immediate_result);
			
	command_buffer_alloc_info : VkCommandBufferAllocateInfo;
	command_buffer_alloc_info.sType = .VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
	command_buffer_alloc_info.commandPool = zr.immediate_command_pool;
	command_buffer_alloc_info.level = .VK_COMMAND_BUFFER_LEVEL_PRIMARY;
	command_buffer_alloc_info.commandBufferCount = 1; 

	immediate_result = vkAllocateCommandBuffers(zr.device, *command_buffer_alloc_info, *zr.immediate_command_buffer);
	if immediate_result != .VK_SUCCESS 
			return false, sprint("%\n", immediate_result);

	queue_deletion(*GLOBAL_DELETION_QUEUE, zr.device, zr.immediate_command_pool);

	return true, "";
}

create_sync_objects :: (zr: *ZRenderer) -> bool, string {
	semaphore_create_info : VkSemaphoreCreateInfo;
	semaphore_create_info.sType = .VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;

	fence_create_info : VkFenceCreateInfo;
	fence_create_info.sType = .VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
	fence_create_info.flags = .VK_FENCE_CREATE_SIGNALED_BIT;

	for zr.frames {
		result := vkCreateSemaphore(zr.device, *semaphore_create_info, null, *it.swapchain_semaphore);
		if result != .VK_SUCCESS 
			return false, sprint("%\n", result);
		result = vkCreateSemaphore(zr.device, *semaphore_create_info, null, *it.render_semaphore);
		if result != .VK_SUCCESS 
			return false, sprint("%\n", result);

		result = vkCreateFence(zr.device, *fence_create_info, null, *it.render_fence);
		if result != .VK_SUCCESS 
			return false, sprint("%\n", result);
	}

	result := vkCreateFence(zr.device, *fence_create_info, null, *zr.immediate_fence);
	if result != .VK_SUCCESS 
		return false, sprint("%\n", result);

	queue_deletion(*GLOBAL_DELETION_QUEUE, zr.device, zr.immediate_fence);
	return true, "";
}

generate_default_images :: (zr: *ZRenderer) {
	white_image := create_image(zr, *color_to_bytes(COLOR_WHITE), .{1,1,1}, .VK_FORMAT_R8G8B8A8_UNORM, .VK_IMAGE_USAGE_SAMPLED_BIT, false, 0, "Image_White");
	white_image.image_index = xx zr.descriptor_writer.write_image(*zr.descriptor_writer, *zr.image_descriptor_buffer, white_image.image_view, .VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL);
	white_image.image_name = "white_image";
	table_add(*zr.image_table, white_image.image_name, white_image);

	grey_image := create_image(zr, *color_to_bytes(COLOR_GREY), .{1,1,1}, .VK_FORMAT_R8G8B8A8_UNORM, .VK_IMAGE_USAGE_SAMPLED_BIT, false, 0, "Image_Grey");
	grey_image.image_index = xx zr.descriptor_writer.write_image(*zr.descriptor_writer, *zr.image_descriptor_buffer, grey_image.image_view, .VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL);
	grey_image.image_name = "grey_image";
	table_add(*zr.image_table, grey_image.image_name, grey_image);

	black_image := create_image(zr, *color_to_bytes(COLOR_BLACK), .{1,1,1}, .VK_FORMAT_R8G8B8A8_UNORM, .VK_IMAGE_USAGE_SAMPLED_BIT, false, 0, "Image_Black");
	black_image.image_index = xx zr.descriptor_writer.write_image(*zr.descriptor_writer, *zr.image_descriptor_buffer, black_image.image_view, .VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL);
	black_image.image_name = "black_image";
	table_add(*zr.image_table, black_image.image_name, black_image);

	pixels : [16*16][4]u8;
	x, y : u32;
	for *pixels {  
		x_block := x / 2;
		y_block := y / 2;
		if (x_block + y_block) % 2 == 0 {
			<<it = color_to_bytes(COLOR_BLACK);
		} else {
			<<it = color_to_bytes(COLOR_MAGENTA);
		}
		x += 1;
		if x == 16 {
			y += 1;
			x = 0;
		}
	}
	
	error_checkerboard := create_image(zr, pixels.data, .{16,16,1}, .VK_FORMAT_R8G8B8A8_UNORM, .VK_IMAGE_USAGE_SAMPLED_BIT, false, 0, "Image_Error");
	error_checkerboard.image_index = xx zr.descriptor_writer.write_image(*zr.descriptor_writer, *zr.image_descriptor_buffer, error_checkerboard.image_view, .VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL);
	error_checkerboard.image_name = "error_image";
	table_add(*zr.image_table, error_checkerboard.image_name, error_checkerboard);

	zr.draw_image.image_index = xx zr.descriptor_writer.write_image(
        *zr.descriptor_writer, 
        *zr.image_descriptor_buffer, 
        zr.draw_image.image_view, 
        .VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL
    );
}

create_default_samplers :: (zr: *ZRenderer) {
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

	vkCreateSampler(zr.device, *sampler_info, null, *zr.samplers[SAMPLER_TYPE.NEAREST]);

	sampler_info.magFilter = .VK_FILTER_LINEAR;
	sampler_info.minFilter = .VK_FILTER_LINEAR;
	vkCreateSampler(zr.device, *sampler_info, null, *zr.samplers[SAMPLER_TYPE.LINEAR]);

	for sampler: zr.samplers {
		queue_deletion(*GLOBAL_DELETION_QUEUE, zr.device, sampler);
	}
}

create_default_materials :: (zr: *ZRenderer) {
	mi_default : Material_Instance;
	mi_default.color_factors = .{1,1,1,1};
	image, success := table_find(*zr.image_table, "error_image");
	if !success {
		panic("Could not find error_image");
	}
	mi_default.albedo_image_index = image.image_index;
	mi_default.albedo_sampler = SAMPLER_TYPE.NEAREST;
	mi_default.type = .OPAQUE;
	zr.mi_default = zr.m_opaque.create_material_instance(*zr.m_opaque, zr, *mi_default);

	mi_debug_wireframe : Debug_Material_Instance;
	mi_debug_wireframe.color_factors = .{1,0,0,1};
	zr.debug_system.mi_debug_wireframe = zr.debug_system.m_debug_wireframe.create_material_instance(*zr.debug_system.m_debug_wireframe, zr, *mi_debug_wireframe);
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

create_image :: (zr: *ZRenderer, size: VkExtent3D, format: VkFormat, usage: VkImageUsageFlags, mip_mapped: bool = false, mip_levels : u32 = 0, name: string = "") -> Allocated_Image {
	if(ENABLE_VALIDATION_LAYERS && name == "") {
		panic_no_name("image");
	}

	new_image : Allocated_Image;
	new_image.image_format = format;
	new_image.image_extent = size;

	image_info := vkinit_image_create_info(format, usage, size);
	if mip_mapped {
		if mip_levels == 0 {
			image_info.mipLevels = get_mip_levels(size.width, size.height);
		}
		else {
			image_info.mipLevels = mip_levels;
		}
	}

	// Allocate on GPU memory always-ish
	allocation_info : VmaAllocationCreateInfo;
	allocation_info.usage = .VMA_MEMORY_USAGE_GPU_ONLY;
	allocation_info.requiredFlags = .VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT;

	// Allocate and create
	result := vmaCreateImage(VMA_ALLOCATOR, *image_info, *allocation_info, *new_image.image, *new_image.allocation, null);
	if result != .VK_SUCCESS {
		panic(sprint("VK ERROR: Could not create image, %", result));
	}
	if(ENABLE_VALIDATION_LAYERS) {
		set_vk_object_name(zr.device, .IMAGE, cast(u64)new_image.image, name);
	}

	// Set correct aspect in case its depth image
	aspect_flag : VkImageAspectFlags = .VK_IMAGE_ASPECT_COLOR_BIT;
	if format == .VK_FORMAT_D32_SFLOAT {
		aspect_flag = .VK_IMAGE_ASPECT_DEPTH_BIT;
	}

	// Make image view
	view_info : VkImageViewCreateInfo = vkinit_imageview_create_info(format, new_image.image, aspect_flag);
	view_info.subresourceRange.levelCount = image_info.mipLevels;
	
	result = vkCreateImageView(zr.device, *view_info, null, *new_image.image_view);
	if result != .VK_SUCCESS {
		panic(sprint("VK ERROR: Could not create imageview, %", result));
	}

	if(ENABLE_VALIDATION_LAYERS) {
		set_vk_object_name(zr.device, .IMAGE_VIEW, cast(u64)new_image.image_view, sprint("%_View", name));
	}

	return new_image;
}

create_image :: (zr: *ZRenderer, data: *void, size: VkExtent3D, format: VkFormat, usage: VkImageUsageFlags, mip_mapped : bool = false, mip_levels : u32 = 0, name: string = "") -> Allocated_Image {
	pixel_size := get_pixel_format_size(format);
	if pixel_size < 1 {
		panic("Pixel format size not found, add it to get_pixel_format_size or don't use it");
	}
	data_size := size.width * size.height * size.depth * xx,no_check pixel_size;
	upload_buffer : Allocated_Buffer = create_buffer(VMA_ALLOCATOR, data_size, .VK_BUFFER_USAGE_TRANSFER_SRC_BIT, .VMA_MEMORY_USAGE_CPU_TO_GPU, zr.device, "Temp Buffer");

	memcpy(upload_buffer.info.pMappedData, data, data_size);

	new_image : Allocated_Image = create_image(zr, size, format, usage | .VK_IMAGE_USAGE_TRANSFER_DST_BIT | .VK_IMAGE_USAGE_TRANSFER_SRC_BIT, mip_mapped, mip_levels, name);

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

	destroy_buffer(VMA_ALLOCATOR, *upload_buffer);

	return new_image;
}

destroy_image :: (image: Allocated_Image) {
	
}