#import "Basic";
#import "Math";
#import "SDL";
#import "Flat_Pool";
#import "Hash_Table";
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
	samplers		: [..] struct {device: VkDevice; sampler: VkSampler;};

	flush_deletion_queue :: (using self: *Deletion_Queue) {
		for <image_views {
			vkDestroyImageView(it.device, it.view, null);
		}
		for <images {
			vmaDestroyImage(it.allocator, it.image, it.allocation);
		}
		for <desc_allocators {
			it.allocator.destroy_pools(it.allocator, it.device);
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
		for <samplers {
			vkDestroySampler(it.device, it.sampler, null);
		}
		array_reset(*image_views);
		array_reset(*images);
		array_reset(*desc_layouts);
		array_reset(*pipeline_layouts);
		array_reset(*pipelines);
		array_reset(*command_pools);
		array_reset(*fences);
		array_reset(*buffers);
		array_reset(*samplers);
	}
}


ZRenderer :: struct {
    // Core state
    initialized             : bool;
    frame_num              	: u32;
    do_render              	: bool;
    render_scale           	: float = 1;
    current_frame          	: u8;
    
    // Window & surface
    window                 	: *SDL_Window;
    window_extents         	: VkExtent2D;
    surface                	: VkSurfaceKHR;
    
    // Resize handling
    resize_requested       	: bool;
    framebuffer_resized		: bool;
    minimized             	: bool;
    
    // Vulkan instance & device
    instance              	: VkInstance;
    debug_messenger       	: VkDebugUtilsMessengerEXT;
    physical_device       	: VkPhysicalDevice;
    logical_device        	: VkDevice;
    allocator             	: VmaAllocator;

	// GPU Scene
	scene_data				: GPU_Scene_Data;
    
    // Queues
    queue_indices         	: Queue_Family_Indices;
    graphics_queue        	: VkQueue;
    present_queue         	: VkQueue;
    
    // Swapchain
    swapchain_details     	: Swapchain_Support_Details;
    swapchain             	: VkSwapchainKHR;
    swapchain_images      	: [..]VkImage;
    swapchain_image_format	: VkFormat;
    swapchain_extent      	: VkExtent2D;
    swapchain_imageviews  	: [..]VkImageView;
    swapchain_framebuffers	: [..]VkFramebuffer;
    
    // Render targets
    draw_image            	: Allocated_Image;
    draw_extent           	: VkExtent2D;
    depth_image           	: Allocated_Image;
    
    // Render pass & pipelines
    render_pass           	: VkRenderPass;
    pipeline_layout       	: VkPipelineLayout;
    graphics_pipeline     	: VkPipeline;
    gradient_pipeline_layout: VkPipelineLayout;
    gradient_pipeline     	: VkPipeline;
    mesh_pipeline_layout  	: VkPipelineLayout;
    mesh_pipeline         	: VkPipeline;
    
    // Descriptors
    global_desc_allocator 	: Descriptor_Allocator;
    draw_image_desc_layout	: VkDescriptorSetLayout;
    draw_image_descriptors  : VkDescriptorSet;
	gpu_scene_data_desc_layout : VkDescriptorSetLayout;
    
    // Per-frame data
    frame_data            	: [MAX_FRAMES_IN_FLIGHT]Frame_Data;
    
    // Immediate mode rendering
    immediate_command_pool  : VkCommandPool;
    immediate_command_buffer: VkCommandBuffer;
    immediate_fence         : VkFence;
    
    // Mesh data
    mesh_pool            	: Flat_Pool;
    meshes               	: [..]Mesh_Asset;
    mesh_map             	: Table(string, *Mesh_Asset);

	// Textures
	white_image				: Allocated_Image;
	black_image				: Allocated_Image;
	grey_image				: Allocated_Image;
	error_checkerboard		: Allocated_Image;

	default_sampler_linear	: VkSampler;
	default_sampler_nearest	: VkSampler;

	image_descriptor_layout : VkDescriptorSetLayout;
    
    // Cleanup
    deletion_queue        	: Deletion_Queue;
    
    // Methods
    get_current_frame_data :: (using self: *ZRenderer) -> *Frame_Data {
        return *frame_data[current_frame];
    }
}

flush_meshes :: (zr: *ZRenderer) {
	for mesh: zr.meshes {
		destroy_buffer(zr.allocator, *mesh.mesh_buffers.vertex_buffer);
		destroy_buffer(zr.allocator, *mesh.mesh_buffers.index_buffer);
	}
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

	fp.init(*zr.mesh_pool);
	allocator := Allocator.{fp.flat_pool_allocator_proc, *zr.mesh_pool};
	zr.meshes.allocator = allocator;

	init_default_data(zr);

	load_glt_meshes(zr, "H:/PBEMJai/content/meshes/basicmesh.glb");

	zr.initialized = true;
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
	init_mesh_pipeline(zr);
	return true, "";
}

draw_frame :: (zr: *ZRenderer) {
	if zr.swapchain_extent.width == 0 || zr.swapchain_extent.height == 0 {
        return;
    }
	frame_data := zr.get_current_frame_data(zr);
	vkWaitForFences(zr.logical_device, 1, *frame_data.render_fence, VK_TRUE, U64_MAX);

	image_idx : u32;
	acquire_result := vkAcquireNextImageKHR(zr.logical_device, zr.swapchain, U64_MAX, frame_data.swapchain_semaphore, VK_NULL_HANDLE, *image_idx);
	if acquire_result == .VK_ERROR_OUT_OF_DATE_KHR {
		zr.resize_requested = true;
		return;
	}
	if acquire_result != .VK_SUCCESS && acquire_result != .VK_SUBOPTIMAL_KHR {
		print("ERROR: %\n", acquire_result);
		return;
	}

	frame_data.deletion_queue.flush_deletion_queue(*frame_data.deletion_queue);
	frame_data.frame_descriptors.clear_pools(*frame_data.frame_descriptors, zr.logical_device);

	zr.draw_extent.height = cast,no_check(u32)(min(zr.swapchain_extent.height, zr.draw_image.image_extent.height) * zr.render_scale);
	zr.draw_extent.width = cast,no_check(u32)(min(zr.swapchain_extent.width, zr.draw_image.image_extent.width) * zr.render_scale);

	vkResetFences(zr.logical_device, 1, *frame_data.render_fence);

	vkResetCommandBuffer(frame_data.command_buffer, 0);

	begin_info := vkinit_command_buffer_begin_info();

    vkBeginCommandBuffer(frame_data.command_buffer, *begin_info);

	 // Transition main draw image into general layout so we can write to it
    vkutil_transition_image(frame_data.command_buffer, zr.draw_image.image, .VK_IMAGE_LAYOUT_UNDEFINED, .VK_IMAGE_LAYOUT_GENERAL, .VK_IMAGE_ASPECT_COLOR_BIT);

	vkutil_transition_image(frame_data.command_buffer, zr.draw_image.image, .VK_IMAGE_LAYOUT_GENERAL, .VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL, .VK_IMAGE_ASPECT_COLOR_BIT);
	vkutil_transition_image(frame_data.command_buffer, zr.depth_image.image, .VK_IMAGE_LAYOUT_UNDEFINED, .VK_IMAGE_LAYOUT_DEPTH_ATTACHMENT_OPTIMAL, .VK_IMAGE_ASPECT_DEPTH_BIT);

	draw_geometry(zr, frame_data.command_buffer);
	//

	// Transition the draw image and the swapchain image into their correct transfer layouts
    vkutil_transition_image(frame_data.command_buffer, zr.draw_image.image, .VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL, .VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, .VK_IMAGE_ASPECT_COLOR_BIT);
	vkutil_transition_image(frame_data.command_buffer, zr.swapchain_images[image_idx], .VK_IMAGE_LAYOUT_UNDEFINED, .VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, .VK_IMAGE_ASPECT_COLOR_BIT);

	// Execute a copy from the draw image into the swapchain
    vkutil_blit_copy_image_image(frame_data.command_buffer, zr.draw_image.image, zr.swapchain_images[image_idx], zr.draw_extent, zr.swapchain_extent);

    // set swapchain image layout to Present so we can show it on the screen
    vkutil_transition_image(frame_data.command_buffer, zr.swapchain_images[image_idx], .VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, .VK_IMAGE_LAYOUT_PRESENT_SRC_KHR, .VK_IMAGE_ASPECT_COLOR_BIT);

	vkEndCommandBuffer(frame_data.command_buffer);

	submit_info : VkSubmitInfo2;
	submit_info.sType = .VK_STRUCTURE_TYPE_SUBMIT_INFO_2;

	wait_semaphore_info : VkSemaphoreSubmitInfo = vkinit_semaphore_submit_info(
		frame_data.swapchain_semaphore,
		VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT_KHR
    );
	
	submit_info.waitSemaphoreInfoCount = 1;
	submit_info.pWaitSemaphoreInfos = *wait_semaphore_info;

	signal_semaphore_info : VkSemaphoreSubmitInfo = vkinit_semaphore_submit_info(
        frame_data.render_semaphore,
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

	result := vkQueueSubmit2(zr.graphics_queue, 1, *submit_info, frame_data.render_fence);
	if result != .VK_SUCCESS {
		print("%\n", result);
		return;
	}
		
	present_info : VkPresentInfoKHR;
	present_info.sType = .VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
	present_info.waitSemaphoreCount = 1;
	present_info.pWaitSemaphores = *frame_data.render_semaphore;

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
	if present_result == .VK_ERROR_OUT_OF_DATE_KHR {
		zr.resize_requested = true;
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
	frame_data := zr.get_current_frame_data(zr);;
	// Begin a render pass connected to our draw image
	color_attachment : VkRenderingAttachmentInfo = vkinit_attachment_info(zr.draw_image.image_view, null, .VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL);
	depth_attachment : VkRenderingAttachmentInfo = vkinit_depth_attachment_info(zr.depth_image.image_view, .VK_IMAGE_LAYOUT_DEPTH_ATTACHMENT_OPTIMAL);

	render_info : VkRenderingInfo = vkinit_rendering_info(zr.draw_extent, *color_attachment, *depth_attachment);
	vkCmdBeginRendering(command_buffer, *render_info);

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
	
	// Allocated onto heap, ok?
	gpu_scene_data_buffer := New(Allocated_Buffer);
	<<gpu_scene_data_buffer = create_buffer(zr, size_of(GPU_Scene_Data), .VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT, .VMA_MEMORY_USAGE_CPU_TO_GPU, "Frame Buffer");

	array_add(*frame_data.deletion_queue.buffers, .{zr.allocator, gpu_scene_data_buffer});

	// Weird way of doing it but sets scene_uniform_data to be equal to zr.scene_data
	void_ptr : *void;
	vmaMapMemory(zr.allocator, gpu_scene_data_buffer.allocation, *void_ptr);
	scene_uniform_data : *GPU_Scene_Data = cast,no_check(*GPU_Scene_Data)void_ptr;
	<<scene_uniform_data = zr.scene_data;

	global_descriptor := frame_data.frame_descriptors.allocate(*frame_data.frame_descriptors, zr.logical_device, zr.gpu_scene_data_desc_layout);

	writer : Descriptor_Writer;
	writer.write_buffer(*writer, 0, gpu_scene_data_buffer.buffer, size_of(GPU_Scene_Data), 0, .VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER);
	writer.update_set(*writer, zr.logical_device, global_descriptor);

	vkCmdBindPipeline(command_buffer, .VK_PIPELINE_BIND_POINT_GRAPHICS, zr.mesh_pipeline);

	image_set : VkDescriptorSet = frame_data.frame_descriptors.allocate(*frame_data.frame_descriptors, zr.logical_device, zr.image_descriptor_layout);
	writer_image : Descriptor_Writer;
	writer_image.write_image(*writer_image, 0, zr.error_checkerboard.image_view, zr.default_sampler_nearest, .VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL, .VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER);
	writer_image.update_set(*writer_image, zr.logical_device, image_set);

	vkCmdBindDescriptorSets(command_buffer, .VK_PIPELINE_BIND_POINT_GRAPHICS, zr.mesh_pipeline_layout, 0, 1, *image_set, 0, null);


	mesh_to_draw, success := table_find(*zr.mesh_map, "Suzanne");
	if !success {
		panic("Could not find mesh asset\n");
	}

	push_constants : GPU_Draw_Push_Constants;
	push_constants.world_matrix = Matrix4_Identity;
	push_constants.vertex_buffer = mesh_to_draw.mesh_buffers.vertex_buffer_address;

	view := make_translation_matrix4(Vector3.{0, 0, -5});
	fov_degrees := 70.0;
	fov_radians := fov_degrees * PI / 180.0;
	aspect_ratio := cast(float)zr.draw_extent.width / cast(float)zr.draw_extent.height;

	projection := make_projection_matrix(
		fov_vertical = fov_radians,
		aspect_ratio_horizontal_over_vertical = aspect_ratio,
		z_near = 10000,
		z_far = 0.1,
		depth_range_01 = true  // Important for Vulkan
	);
	projection._22 *= -1;

	push_constants.world_matrix =  projection * view;
	push_constants.world_matrix = transpose(push_constants.world_matrix);

	vkCmdPushConstants(command_buffer, zr.mesh_pipeline_layout, .VK_SHADER_STAGE_VERTEX_BIT, 0, size_of(GPU_Draw_Push_Constants), *push_constants);
	vkCmdBindIndexBuffer(command_buffer, mesh_to_draw.mesh_buffers.index_buffer.buffer, 0, .VK_INDEX_TYPE_UINT32);

	vkCmdDrawIndexed(command_buffer, xx mesh_to_draw.surfaces[0].count, 1, mesh_to_draw.surfaces[0].start_index, 0, 0);
	
	vkCmdEndRendering(command_buffer);
}

deinit_zrenderer :: (zr: *ZRenderer) {
	if zr.initialized {
		vkDeviceWaitIdle(zr.logical_device); // Wait for it to finish whatever its doing

		for zr.swapchain_framebuffers {
			vkDestroyFramebuffer(zr.logical_device, it, null);
		}
		destroy_swapchain(zr);

		vkDestroyPipeline(zr.logical_device, zr.graphics_pipeline, null);
		vkDestroyPipelineLayout(zr.logical_device, zr.pipeline_layout, null);

		vkDestroyRenderPass(zr.logical_device, zr.render_pass, null);

		for zr.frame_data {
			vkDestroySemaphore(zr.logical_device, it.swapchain_semaphore, null);
			vkDestroySemaphore(zr.logical_device, it.render_semaphore, null);
			vkDestroyFence(zr.logical_device, it.render_fence, null);
			vkDestroyCommandPool(zr.logical_device, it.command_pool, null);
			it.frame_descriptors.destroy_pools(*it.frame_descriptors, zr.logical_device);

			it.deletion_queue.flush_deletion_queue(*it.deletion_queue);
		}

		zr.deletion_queue.flush_deletion_queue(*zr.deletion_queue);

	/*	vkDestroyImageView(zr.logical_device, zr.white_image.image_view, null);
		vmaDestroyImage(zr.allocator, zr.white_image.image, zr.white_image.allocation);
		*/
		flush_meshes(zr);

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

