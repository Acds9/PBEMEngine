#import "Basic";
#import "Math";
#import "SDL";
ImGui :: #import "ImGui";

SDL_Vulkan_GetInstanceExtensions :: (window : *SDL_Window, num_extensions : *u32, extensions : **u8) -> SDL_bool #foreign SDL2;
SDL_Vulkan_CreateSurface :: (window : *SDL_Window, instance : VkInstance, surface : *VkSurfaceKHR) -> SDL_bool #foreign SDL2;
SDL_Vulkan_GetDrawableSize :: (window : *SDL_Window, w : *u32, h : *u32) #foreign SDL2;

MAX_FRAMES_IN_FLIGHT :: 2;


Deletion_Queue :: struct {
	image_views		: [..] struct {device: VkDevice; view: VkImageView;};
	images 			: [..] struct {allocator: VmaAllocator; image: VkImage; allocation: VmaAllocation;};
	desc_allocators : [..] struct {device: VkDevice; allocator: *Descriptor_Allocator;};
	desc_layouts	: [..] struct {device: VkDevice; layout: VkDescriptorSetLayout;};
	pipelines		: [..] struct {device: VkDevice; pipeline: VkPipeline;};
	pipeline_layouts: [..] struct {device: VkDevice; layout: VkPipelineLayout;};
	command_pools	: [..] struct {device: VkDevice; pool: VkCommandPool;};
	fences			: [..] struct {device: VkDevice; fence: VkFence;};
	buffers			: [..] struct {allocator: VmaAllocator; buffer: *Allocated_Buffer;};
}

flush_deletion_queue :: (queue: *Deletion_Queue) {
	using queue;
	for <image_views {
		vkDestroyImageView(it.device, it.view, null);
	}
	for <images {
		vmaDestroyImage(it.allocator, it.image, it.allocation);
	}
	for <desc_allocators {
		vkDestroyDescriptorPool(it.device, it.allocator.pool, null);
	}
	for <desc_layouts {
		vkDestroyDescriptorSetLayout(it.device, it.layout, null);
	}
	for <pipeline_layouts {
		vkDestroyPipelineLayout(it.device, it.layout, null);
	}
	for <pipelines {
		vkDestroyPipeline(it.device, it.pipeline, null);
	}
	for <command_pools {
		vkDestroyCommandPool(it.device, it.pool, null);
	}
	for <fences {
		vkDestroyFence(it.device, it.fence, null);
	}
	for <buffers {
		destroy_buffer(it.allocator, it.buffer);
	}
	array_reset(*image_views);
	array_reset(*images);
	array_reset(*desc_layouts);
	array_reset(*pipeline_layouts);
	array_reset(*pipelines);
	array_reset(*command_pools);
	array_reset(*fences);
	array_reset(*buffers);
}

ZRenderer :: struct {
	
	initialized 			: bool;
	frame_num				: u32;
	do_render				: bool;
	window_extents			: VkExtent2D;
	window					: *SDL_Window;

	instance 				: VkInstance;
	debug_messenger 		: VkDebugUtilsMessengerEXT;
	physical_device 		: VkPhysicalDevice;
	logical_device			: VkDevice;
	surface					: VkSurfaceKHR;

	swapchain_details 		: Swapchain_Support_Details;
	swapchain				: VkSwapchainKHR;
	swapchain_images 		: [..]VkImage;
	swapchain_image_format 	: VkFormat;
	swapchain_extent		: VkExtent2D;
	swapchain_imageviews	: [..]VkImageView;
	swapchain_framebuffers	: [..]VkFramebuffer;

	draw_image				: Allocated_Image;
	draw_extent				: VkExtent2D;

	queue_indices			: Queue_Family_Indices;
	graphics_queue			: VkQueue;
	present_queue			: VkQueue;

	render_pass 			: VkRenderPass;
	pipeline_layout			: VkPipelineLayout;

	graphics_pipeline		: VkPipeline;

	frame_data				: [MAX_FRAMES_IN_FLIGHT]Frame_Data;
	get_current_frame_data :: (using self: *ZRenderer) -> *Frame_Data {
		return *frame_data[current_frame];
	}

	framebuffer_resized			: bool;
	minimized					: bool;
	current_frame				: u8;

	allocator					: VmaAllocator;

	deletion_queue				: Deletion_Queue;

	global_desc_allocator 		: Descriptor_Allocator;

	draw_image_descs			: VkDescriptorSet;
	draw_image_desc_layout 		: VkDescriptorSetLayout;

	gradient_pipeline			: VkPipeline;
	gradient_pipeline_layout	: VkPipelineLayout;

	// IMMEDIATE

	immediate_fence				: VkFence;
	immediate_command_buffer	: VkCommandBuffer;
	immediate_command_pool		: VkCommandPool;

	// TRIANGLE
	triangle_pipeline_layout	: VkPipelineLayout;
	triangle_pipeline			: VkPipeline;

	// MESH
	mesh_pipeline_layout		: VkPipelineLayout;
	mesh_pipeline				: VkPipeline;

	rectangle					: GPU_Mesh_Buffers;
}

init_zrenderer :: (zr: *ZRenderer) -> bool, string {
	SDL_Init(SDL_INIT_VIDEO);
	zr.window = SDL_CreateWindow(
								"Z-Engine", 
								SDL_WINDOWPOS_UNDEFINED, 
								SDL_WINDOWPOS_UNDEFINED, 
								xx WINDOW_WIDTH, 
								xx WINDOW_HEIGHT, 
								SDL_WINDOW_VULKAN|SDL_WINDOW_RESIZABLE);
    if zr.window == null {
        return false, sprint("Could not create window: %\n", to_string(SDL_GetError()));
    }

	success : bool;
	error	: string;
	success, error = init_instance(zr);
	if !success return false, error;
	success, error = create_surface(zr);
	if !success return false, error;
	success, error = select_physical_device(zr);
	if !success return false, error;
	success, error = create_logical_device(zr);
	if !success return false, error;
	success, error = init_validation(zr);
	if !success return false, error;
	success, error = create_vma_allocator(zr);
	if !success return false, error;
	success, error = init_swapchain(zr);
	if !success return false, error;
	success, error = create_render_pass(zr);
	if !success return false, error;
	success, error = create_framebuffers(zr);
	if !success return false, error;
	success, error = init_commands(zr);
	if !success return false, error;
	success, error = create_sync_objects(zr);
	if !success return false, error;
	success, error = init_descriptors(zr);
	if !success return false, error;
	success, error = init_pipelines(zr);
	if !success return false, error;
	

	init_default_data(zr);
	zr.initialized = true;
	return true, "";
}

recreate_swapchain :: (zr: *ZRenderer) -> bool, string {
	w : u32;
	h : u32;
	SDL_Vulkan_GetDrawableSize(zr.window, *w, *h);
	while(w == 0 || h == 0) {
		SDL_Vulkan_GetDrawableSize(zr.window, *w, *h);
		SDL_WaitEvent(null);
	}
		
	vkDeviceWaitIdle(zr.logical_device);
	deinit_swapchain(zr);

	query_success := query_swapchain_support(zr);
    if !query_success return false, "Failed to query swapchain support";
	success, error := init_swapchain(zr);
	if !success return false, error;
	success, error = create_framebuffers(zr);
	if !success return false, error;

	return true, "";
}

immediate_submit :: (zr: *ZRenderer, body: Code) #expand {
	vkResetFences(zr.logical_device, 1, *zr.immediate_fence);
	vkResetCommandBuffer(zr.immediate_command_buffer, 0);

	`cmd := zr.immediate_command_buffer;

	cmd_begin_info : VkCommandBufferBeginInfo = vkinit_command_buffer_begin_info(.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT);
	vkBeginCommandBuffer(cmd, *cmd_begin_info);

	#insert body;

	vkEndCommandBuffer(cmd);

	cmd_info : VkCommandBufferSubmitInfo = vkinit_command_buffer_submit_info(cmd);
	submit_info : VkSubmitInfo2 = vk_init_submit_info2(*cmd_info, null, null);

	vkQueueSubmit2(zr.graphics_queue, 1, *submit_info, zr.immediate_fence);

	vkWaitForFences(zr.logical_device, 1, *zr.immediate_fence, 1, 1000000000);
}

init_pipelines :: (zr: *ZRenderer) -> bool, string {
	init_background_pipelines(zr);
	init_triangle_pipeline(zr);
	init_mesh_pipeline(zr);
	return true, "";
}

draw_frame :: (zr: *ZRenderer) {
	if zr.swapchain_extent.width == 0 || zr.swapchain_extent.height == 0 {
        return;
    }
	frame_data := zr.get_current_frame_data(zr);
	vkWaitForFences(zr.logical_device, 1, *frame_data.in_flight_fence, VK_TRUE, U64_MAX);

	image_idx : u32;
	acquire_result := vkAcquireNextImageKHR(zr.logical_device, zr.swapchain, U64_MAX, frame_data.image_available_semaphore, VK_NULL_HANDLE, *image_idx);
	if acquire_result == .VK_ERROR_OUT_OF_DATE_KHR {
		recreate_swapchain(zr);
		return;
	}
	if acquire_result != .VK_SUCCESS && acquire_result != .VK_SUBOPTIMAL_KHR {
		print("ERROR: %\n", acquire_result);
		return;
	}
	vkResetFences(zr.logical_device, 1, *frame_data.in_flight_fence);

	vkResetCommandBuffer(frame_data.command_buffer, 0);

	begin_info := vkinit_command_buffer_begin_info();

    vkBeginCommandBuffer(frame_data.command_buffer, *begin_info);

	 // Transition main draw image into general layout so we can write to it
    vkutil_transition_image(frame_data.command_buffer, zr.draw_image.image, .VK_IMAGE_LAYOUT_UNDEFINED, .VK_IMAGE_LAYOUT_GENERAL);

	// THIS IS WHERE WE DO STUFF
	draw_gradient_background(zr, frame_data.command_buffer);

	vkutil_transition_image(frame_data.command_buffer, zr.draw_image.image, .VK_IMAGE_LAYOUT_GENERAL, .VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL);

	draw_geometry(zr, frame_data.command_buffer);
	//

	// Transition the draw image and the swapchain image into their correct transfer layouts
    vkutil_transition_image(frame_data.command_buffer, zr.draw_image.image, .VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL, .VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL);
	vkutil_transition_image(frame_data.command_buffer, zr.swapchain_images[image_idx], .VK_IMAGE_LAYOUT_UNDEFINED, .VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL);

	// Execute a copy from the draw image into the swapchain
    vkutil_blit_copy_image_image(frame_data.command_buffer, zr.draw_image.image, zr.swapchain_images[image_idx], zr.draw_extent, zr.swapchain_extent);

    // set swapchain image layout to Present so we can show it on the screen
    vkutil_transition_image(frame_data.command_buffer, zr.swapchain_images[image_idx], .VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, .VK_IMAGE_LAYOUT_PRESENT_SRC_KHR);

	vkEndCommandBuffer(frame_data.command_buffer);

	submit_info : VkSubmitInfo2;
	submit_info.sType = .VK_STRUCTURE_TYPE_SUBMIT_INFO_2;

	wait_semaphore_info : VkSemaphoreSubmitInfo = vkinit_semaphore_submit_info(
		frame_data.image_available_semaphore,
		VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT_KHR
    );
	
	submit_info.waitSemaphoreInfoCount = 1;
	submit_info.pWaitSemaphoreInfos = *wait_semaphore_info;

	signal_semaphore_info : VkSemaphoreSubmitInfo = vkinit_semaphore_submit_info(
        frame_data.render_finished_semaphore,
        VK_PIPELINE_STAGE_2_ALL_GRAPHICS_BIT
    );

	submit_info.signalSemaphoreInfoCount  = 1;
	submit_info.pSignalSemaphoreInfos  = *signal_semaphore_info;

	command_buffer_submit_info : VkCommandBufferSubmitInfo;
	command_buffer_submit_info.sType = .VK_STRUCTURE_TYPE_COMMAND_BUFFER_SUBMIT_INFO;
	command_buffer_submit_info.commandBuffer = frame_data.command_buffer;
	command_buffer_submit_info.deviceMask = 0;

	submit_info.commandBufferInfoCount = 1;
	submit_info.pCommandBufferInfos = *command_buffer_submit_info;

	result := vkQueueSubmit2(zr.graphics_queue, 1, *submit_info, frame_data.in_flight_fence);
	if result != .VK_SUCCESS {
		print("%\n", result);
		return;
	}
		
	present_info : VkPresentInfoKHR;
	present_info.sType = .VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
	present_info.waitSemaphoreCount = 1;
	present_info.pWaitSemaphores = *frame_data.render_finished_semaphore;

	swap_chains : [..]VkSwapchainKHR;
	array_add(*swap_chains, zr.swapchain);
	present_info.swapchainCount = 1;
	present_info.pSwapchains = swap_chains.data;
	present_info.pImageIndices = *image_idx;
	present_info.pResults = null;

	zr.current_frame = zr.current_frame + 1;
	if zr.current_frame >= MAX_FRAMES_IN_FLIGHT{
		zr.current_frame = 0;
	}

	present_result := vkQueuePresentKHR(zr.present_queue, *present_info);
	if present_result == .VK_ERROR_OUT_OF_DATE_KHR || present_result == .VK_SUBOPTIMAL_KHR || zr.framebuffer_resized {
		zr.framebuffer_resized = false;
		recreate_swapchain(zr);
	}
	if present_result != .VK_SUCCESS {
		if present_result == .ERROR_OUT_OF_DATE_KHR {
			print("MSG (VK): Resizing...\n");
		}
		else print("ERROR (VK): %\n", present_result);
		return;
	}
}

draw_geometry :: (zr: *ZRenderer, command_buffer: VkCommandBuffer ) {
	// Begin a render pass connected to our draw image
	color_attachment : VkRenderingAttachmentInfo = vkinit_attachment_info(zr.draw_image.image_view, null, .VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL);

	render_info : VkRenderingInfo = vkinit_rendering_info(zr.draw_extent, *color_attachment, null);
	vkCmdBeginRendering(command_buffer, *render_info);

	vkCmdBindPipeline(command_buffer, .VK_PIPELINE_BIND_POINT_GRAPHICS, zr.triangle_pipeline);

	// Set dynamic viewport and scissor
	viewport : VkViewport;
	viewport.x = 0;
	viewport.y = 0;
	viewport.width = cast,no_check(float)zr.draw_extent.width;
	viewport.height = cast,no_check(float)zr.draw_extent.height;
	viewport.minDepth = 0;
	viewport.maxDepth = 1;

	vkCmdSetViewport(command_buffer, 0, 1, *viewport);

	scissor : VkRect2D;
	scissor.offset.x = 0;
	scissor.offset.y = 0;
	scissor.extent.width = zr.draw_extent.width;
	scissor.extent.height = zr.draw_extent.height;

	vkCmdSetScissor(command_buffer, 0, 1, *scissor);
	
	// Launch a draw command to draw 3 vertices
	vkCmdDraw(command_buffer, 3, 1, 0, 0);
	
	vkCmdBindPipeline(command_buffer, .VK_PIPELINE_BIND_POINT_GRAPHICS, zr.mesh_pipeline);

	push_constants : GPU_Draw_Push_Constants;
	push_constants.world_matrix = Matrix4_Identity;
	push_constants.vertex_buffer = zr.rectangle.vertex_buffer_address;

	vkCmdPushConstants(command_buffer, zr.mesh_pipeline_layout, .VK_SHADER_STAGE_VERTEX_BIT, 0, size_of(GPU_Draw_Push_Constants), *push_constants);
	vkCmdBindIndexBuffer(command_buffer, zr.rectangle.index_buffer.buffer, 0, .VK_INDEX_TYPE_UINT32);

	vkCmdDrawIndexed(command_buffer, 6, 1, 0, 0, 0);
	
	vkCmdEndRendering(command_buffer);
}

deinit_zrenderer :: (zr: *ZRenderer) {
	if zr.initialized {
		vkDeviceWaitIdle(zr.logical_device); // Wait for it to finish whatever its doing

		deinit_swapchain(zr);

		vkDestroyPipeline(zr.logical_device, zr.graphics_pipeline, null);
		vkDestroyPipelineLayout(zr.logical_device, zr.pipeline_layout, null);

		vkDestroyRenderPass(zr.logical_device, zr.render_pass, null);

		for zr.frame_data {
			vkDestroySemaphore(zr.logical_device, it.image_available_semaphore, null);
			vkDestroySemaphore(zr.logical_device, it.render_finished_semaphore, null);
			vkDestroyFence(zr.logical_device, it.in_flight_fence, null);
			vkDestroyCommandPool(zr.logical_device, it.command_pool, null);

			flush_deletion_queue(*it.deletion_queue);
		}

		flush_deletion_queue(*zr.deletion_queue);

		vmaDestroyAllocator(zr.allocator);

		vkDestroyDevice(zr.logical_device, null);

		if ENABLE_VALIDATION_LAYERS {
			deinit_validation(zr, null);
		}

		vkDestroySurfaceKHR(zr.instance, zr.surface, null);
		
		vkDestroyInstance(zr.instance, null);
		
		SDL_DestroyWindow(zr.window);
	}
	SDL_Quit();
}

