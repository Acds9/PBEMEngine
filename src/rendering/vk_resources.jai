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
	vkCmdBindDescriptorSets(command_buffer, .VK_PIPELINE_BIND_POINT_COMPUTE, zr.gradient_pipeline_layout, 0, 1, *zr.draw_image_descs, 0, null);

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
		result := vkCreateSemaphore(zr.logical_device, *semaphore_create_info, null, *it.image_available_semaphore);
		if result != .VK_SUCCESS 
			return false, sprint("%\n", result);
		result = vkCreateSemaphore(zr.logical_device, *semaphore_create_info, null, *it.render_finished_semaphore);
		if result != .VK_SUCCESS 
			return false, sprint("%\n", result);

		result = vkCreateFence(zr.logical_device, *fence_create_info, null, *it.in_flight_fence);
		if result != .VK_SUCCESS 
			return false, sprint("%\n", result);
	}

	result := vkCreateFence(zr.logical_device, *fence_create_info, null, *zr.immediate_fence);
	if result != .VK_SUCCESS 
		return false, sprint("%\n", result);

	array_add(*zr.deletion_queue.fences, .{zr.logical_device, zr.immediate_fence});
	return true, "";
}


init_descriptors :: (zr: *ZRenderer) -> bool, string {
	// Pool holds 10 sets, 1 image each
	sizes : [..]Desc_Pool_Size_Ratio;
	array_add(*sizes, .{.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, 1});

	init_descriptor_pool(*zr.global_desc_allocator, zr.logical_device, 10, sizes);

	builder : Descriptor_Layout_Builder;
	add_binding(*builder, 0, .VK_DESCRIPTOR_TYPE_STORAGE_IMAGE);
	_, _, zr.draw_image_desc_layout = build_descriptor_set_layout(*builder, zr.logical_device, .VK_SHADER_STAGE_COMPUTE_BIT);
	
	zr.draw_image_descs = allocate_descriptor_set(*zr.global_desc_allocator, zr.logical_device, zr.draw_image_desc_layout);

	image_info : VkDescriptorImageInfo;
	image_info.imageLayout = .VK_IMAGE_LAYOUT_GENERAL;
	image_info.imageView = zr.draw_image.image_view;

	draw_image_write : VkWriteDescriptorSet;
	draw_image_write.sType = .VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;

	draw_image_write.dstBinding = 0;
	draw_image_write.dstSet = zr.draw_image_descs;
	draw_image_write.descriptorCount = 1;
	draw_image_write.descriptorType = .VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
	draw_image_write.pImageInfo = *image_info;

	vkUpdateDescriptorSets(zr.logical_device, 1, *draw_image_write, 0, null);

	array_add(*zr.deletion_queue.desc_allocators, .{zr.logical_device, *zr.global_desc_allocator});
	array_add(*zr.deletion_queue.desc_layouts, .{zr.logical_device, zr.draw_image_desc_layout});

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
	rect_vertices : [4]Vertex;
	
	rect_vertices[0].position = .{.5,-.5,0};
	rect_vertices[1].position = .{.5,.5,0};
	rect_vertices[2].position = .{-.5,-.5,0};
	rect_vertices[3].position = .{-.5,.5,0};

	rect_vertices[0].color = .{0,0,0,1};
	rect_vertices[1].color = .{.5,.5,.5,1};
	rect_vertices[2].color = .{1,0,0,1};
	rect_vertices[3].color = .{0,1,0,1};

	rect_idx : [6]u32;

	rect_idx[0] = 0;
	rect_idx[1] = 1;
	rect_idx[2] = 2;

	rect_idx[3] = 2;
	rect_idx[4] = 1;
	rect_idx[5] = 3;

	zr.rectangle = upload_mesh(zr, rect_idx, rect_vertices);

	set_vk_object_name(zr.logical_device, .BUFFER, cast(u64)zr.rectangle.index_buffer.buffer, "Rectangle Index Buffer");
	set_vk_object_name(zr.logical_device, .BUFFER, cast(u64)zr.rectangle.vertex_buffer.buffer, "Rectangle Vertex Buffer");

	array_add(*zr.deletion_queue.buffers, .{zr.allocator, *zr.rectangle.index_buffer});
	array_add(*zr.deletion_queue.buffers, .{zr.allocator, *zr.rectangle.vertex_buffer});
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