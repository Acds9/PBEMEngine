#import "Basic";
#import "Math";
#import "SDL";
#import "Flat_Pool";
#import "Hash_Table";
ImGui :: #import "ImGui";

SDL_Vulkan_GetInstanceExtensions :: (window : *SDL_Window, num_extensions : *u32, extensions : **u8) -> SDL_bool #foreign SDL2;
SDL_Vulkan_CreateSurface :: (window : *SDL_Window, instance : VkInstance, surface : *VkSurfaceKHR) -> SDL_bool #foreign SDL2;
SDL_Vulkan_GetDrawableSize :: (window : *SDL_Window, w : *u32, h : *u32) #foreign SDL2;
vkGetDescriptorEXT : PFN_vkGetDescriptorEXT;
vkCmdBindDescriptorBuffersEXT : PFN_vkCmdBindDescriptorBuffersEXT;
vkCmdSetDescriptorBufferOffsetsEXT : PFN_vkCmdSetDescriptorBufferOffsetsEXT;

MAX_FRAMES_IN_FLIGHT :: 2;
DEFAULT_CLEARVALUE :: #run color_to_array(*COLOR_DARK_GREY);

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
    device      		  	: VkDevice;

	// GPU Scene
	camera					: Render_Camera;
    
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
    draw_image            	: Allocated_Image; // This is what we actually draw to, we then blit it onto the swapchain image
    draw_extent           	: VkExtent2D;
    depth_image           	: Allocated_Image;
    
    // Render pass & pipelines
    render_pass           	: VkRenderPass;
    pipeline_layout       	: VkPipelineLayout;

    mesh_pipeline_layout  	: VkPipelineLayout;
    mesh_pipeline         	: VkPipeline;
    
    // Descriptor Buffers
	image_array_layout		: VkDescriptorSetLayout;
	sampler_array_layout	: VkDescriptorSetLayout;

	// These are shared between frames so they don't need to be in the frame data
	descriptor_writer			: Descriptor_Buffer_Writer;
	image_descriptor_buffer 	: Linear_Buffer;
	sampler_descriptor_buffer	: Linear_Buffer; 

	descriptor_buffer_properties : VkPhysicalDeviceDescriptorBufferPropertiesEXT;

    // Per-frame data
    frames            	: [MAX_FRAMES_IN_FLIGHT]Frame_Data;
    
    // Immediate mode rendering
    immediate_command_pool  : VkCommandPool;
    immediate_command_buffer: VkCommandBuffer;
    immediate_fence         : VkFence;
    
    // Mesh data
    mesh_pool            	: Flat_Pool;
    meshes               	: [..]Mesh_Asset;
    mesh_map             	: Table(string, *Mesh_Asset);

	geometry_pool			: GPU_Geometry_Pool; // Maybe split this up later

	material_pool			: Material_Pool;

	// Textures
	image_table				: Table(string, Allocated_Image);

	default_sampler_nearest	: VkSampler;
	sampler_nearest_index	: u32 = 0;
	default_sampler_linear	: VkSampler;
	sampler_linear_index	: u32 = 1;
	

	default_material		: Material_Instance;
	opaque_material			: Material_Pipeline_Opaque;

	default_clearvalue		: VkClearValue;

	frame_surfaces			: Frame_Surface_Buckets;
    
	Frame_Data :: struct {
		command_pool 				: VkCommandPool;
		command_buffer				: VkCommandBuffer;

		swapchain_semaphore 		: VkSemaphore;
		render_semaphore 			: VkSemaphore;
		render_fence				: VkFence;

		camera_buffer				: Allocated_Buffer;

		deletion_queue				: Deletion_Queue;
	}

    // Methods
    get_current_frame_data :: (using self: *ZRenderer) -> *Frame_Data {
        return *frames[current_frame];
    }
}

flush_images :: (zr: *ZRenderer) {
	for *entry: zr.image_table {
		vkDestroyImageView(zr.device, entry.image_view, null);
		vmaDestroyImage(VMA_ALLOCATOR, entry.image, entry.allocation);

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
	success, error = create_vma_allocator(zr.physical_device, zr.device, zr.instance);
	if !success return false, error;
	success, error = init_swapchain(zr);
	if !success return false, error;
	success, error = create_render_pass(zr);
	if !success return false, error;
	success, error = create_framebuffers(zr);
	if !success return false, error;
	success, error = create_sync_objects(zr);
	if !success return false, error;

	init_descriptor_buffers(zr);
	init_descriptor_layouts(zr);
	init_frames(zr);

	success, error = init_commands(zr);
	if !success return false, error;
	success, error = init_pipelines(zr);
	if !success return false, error;

	fp.init(*zr.mesh_pool);
	allocator := Allocator.{fp.flat_pool_allocator_proc, *zr.mesh_pool};
	zr.meshes.allocator = allocator;

	zr.geometry_pool.init(*zr.geometry_pool, zr.device, VMA_ALLOCATOR, GEOPOOL_VERTEX_ALLOC_SIZE, GEOPOOL_INDEX_ALLOC_SIZE);
	zr.material_pool.init(*zr.material_pool, zr.device, VMA_ALLOCATOR, MATERIAL_CONSTANTS_BUFFER_SIZE);
	
	generate_default_images(zr);
	create_default_samplers(zr);
	create_default_materials(zr);
	
	init_camera(*zr.camera);

	load_glt_meshes(zr, "H:/PBEMJai/content/meshes/ship_test.glb");

	zr.initialized = true;
	return true, "";
}

immediate_submit :: (zr: *ZRenderer, body: Code) #expand {
	vkResetFences(zr.device, 1, *zr.immediate_fence);
	vkResetCommandBuffer(zr.immediate_command_buffer, 0);

	`cmd := zr.immediate_command_buffer;

	cmd_begin_info : VkCommandBufferBeginInfo = vkinit_command_buffer_begin_info(.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT);
	vkBeginCommandBuffer(cmd, *cmd_begin_info);

	#insert body;

	vkEndCommandBuffer(cmd);

	cmd_info : VkCommandBufferSubmitInfo = vkinit_command_buffer_submit_info(cmd);
	submit_info : VkSubmitInfo2 = vk_init_submit_info2(*cmd_info, null, null);

	result := vkQueueSubmit2(zr.graphics_queue, 1, *submit_info, zr.immediate_fence);
	result = vkWaitForFences(zr.device, 1, *zr.immediate_fence, 1, 1000000000);
}

init_pipelines :: (zr: *ZRenderer) -> bool, string {
	init_mesh_pipeline(zr);
	return true, "";
}

init_frames :: (zr: *ZRenderer) {
	queue_family_indices := zr.queue_indices;

	pool_info : VkCommandPoolCreateInfo ;
	pool_info.sType = .VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
	pool_info.flags = .VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
	pool_info.queueFamilyIndex = xx queue_family_indices.graphics;

	for *frame: zr.frames {
		// Create cpmmand pool first
		result := vkCreateCommandPool(zr.device, *pool_info, null, *frame.command_pool);
		if result != .VK_SUCCESS 
			panic("Could not create command pool");

		// Now allocate the buffer
		alloc_info : VkCommandBufferAllocateInfo;
		alloc_info.sType = .VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
		alloc_info.commandPool = frame.command_pool;
		alloc_info.level = .VK_COMMAND_BUFFER_LEVEL_PRIMARY;
		alloc_info.commandBufferCount = 1; // Just one tied to this pool, but we have multiple pools
		
		result = vkAllocateCommandBuffers(zr.device, *alloc_info, *frame.command_buffer);
		if result != .VK_SUCCESS 
			panic("Could not create command buffer");

		// Now init the other buffers:
		frame.camera_buffer = create_buffer(VMA_ALLOCATOR, size_of(Render_Camera.GPU_Camera_Data),
										.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT | .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT,
										.VMA_MEMORY_USAGE_CPU_TO_GPU, zr.device,sprint("Frame % Camera Buffer", it_index));
		queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, *frame.camera_buffer);
	}
}

draw_frame :: (zr: *ZRenderer, scene: *ZScene) {
	if zr.swapchain_extent.width == 0 || zr.swapchain_extent.height == 0 {
        return;
    }
	update_scene(zr);

	frame_data := zr.get_current_frame_data(zr);

	// Wait for CPU fence, this will be signalled by the GPU as we pass it in vkQueueSubmit2 further down
	vkWaitForFences(zr.device, 1, *frame_data.render_fence, VK_TRUE, U64_MAX);

	// Ask the swapchain which image index is available for rendering next, it is blocking and will return when an image is available OR an error occurs, see timeout of U64_MAX
	image_idx : u32;
	acquire_result := vkAcquireNextImageKHR(zr.device, zr.swapchain, U64_MAX, frame_data.swapchain_semaphore, VK_NULL_HANDLE, *image_idx);
	if acquire_result == .VK_ERROR_OUT_OF_DATE_KHR {
		zr.resize_requested = true;
		return;
	}
	if acquire_result != .VK_SUCCESS && acquire_result != .VK_SUBOPTIMAL_KHR {
		print("ERROR: %\n", acquire_result);
		return;
	}

	// Flush the frame stuff
	frame_data.deletion_queue.flush_deletion_queue(*frame_data.deletion_queue);
	// Reset frame stuff
	vkResetFences(zr.device, 1, *frame_data.render_fence);
	vkResetCommandBuffer(frame_data.command_buffer, 0);

	// Set the draw image extents to match the swapchain
	zr.draw_extent.height = cast,no_check(u32)(min(zr.swapchain_extent.height, zr.draw_image.image_extent.height) * zr.render_scale);
	zr.draw_extent.width = cast,no_check(u32)(min(zr.swapchain_extent.width, zr.draw_image.image_extent.width) * zr.render_scale);

	begin_info := vkinit_command_buffer_begin_info();

	// Begin the command buffer to record commands, everything after this is command recording
    vkBeginCommandBuffer(frame_data.command_buffer, *begin_info);
	{
		// Transition main draw image (and depth image) into general layout so we can draw into it
		vkutil_transition_image(frame_data.command_buffer, zr.draw_image.image, .VK_IMAGE_LAYOUT_UNDEFINED, .VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL, .VK_IMAGE_ASPECT_COLOR_BIT);
		vkutil_transition_image(frame_data.command_buffer, zr.depth_image.image, .VK_IMAGE_LAYOUT_UNDEFINED, .VK_IMAGE_LAYOUT_DEPTH_ATTACHMENT_OPTIMAL, .VK_IMAGE_ASPECT_DEPTH_BIT);

		// Draw geometry stuff
		draw_geometry(zr, scene, frame_data.command_buffer);
		//

		// Transition the draw image to be copied FROM
		vkutil_transition_image(frame_data.command_buffer, zr.draw_image.image, .VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL, .VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, .VK_IMAGE_ASPECT_COLOR_BIT);
		// Transition the swapchain image to be copied INTO
		vkutil_transition_image(frame_data.command_buffer, zr.swapchain_images[image_idx], .VK_IMAGE_LAYOUT_UNDEFINED, .VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, .VK_IMAGE_ASPECT_COLOR_BIT);

		// Execute a copy from the draw image into the swapchain with blitting
		vkutil_blit_copy_image_image(frame_data.command_buffer, zr.draw_image.image, zr.swapchain_images[image_idx], zr.draw_extent, zr.swapchain_extent);

		// Set the swapchain image layout to be presented to the surface (AKA the window)
		vkutil_transition_image(frame_data.command_buffer, zr.swapchain_images[image_idx], .VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, .VK_IMAGE_LAYOUT_PRESENT_SRC_KHR, .VK_IMAGE_ASPECT_COLOR_BIT);
	}
	// End command recording to this buffer
	vkEndCommandBuffer(frame_data.command_buffer);

	// Create info for command buffer submission
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

	// Actually submit the command buffer for the GPU to start working on
	result := vkQueueSubmit2(zr.graphics_queue, 1, *submit_info, frame_data.render_fence);
	if result != .VK_SUCCESS {
		print("%\n", result);
		vkResetCommandBuffer(frame_data.command_buffer, 0);
		return;
	}
	
	// Prepare info to present an image to the surface
	present_info : VkPresentInfoKHR;
	present_info.sType = .VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
	present_info.waitSemaphoreCount = 1;
	present_info.pWaitSemaphores = *frame_data.render_semaphore;

	// If we want to have mulltimonitor windows later, we can create and pass a pointer to an array of swapchains
	present_info.swapchainCount = 1;
	present_info.pSwapchains = *zr.swapchain;
	present_info.pImageIndices = *image_idx;
	present_info.pResults = null;

	// Increment the frame
	zr.current_frame = zr.current_frame + 1;
	if zr.current_frame >= MAX_FRAMES_IN_FLIGHT{
		zr.current_frame = 0;
	}

	// Actually present the image on the surface/window
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

draw_geometry :: (zr: *ZRenderer, scene: *ZScene, command_buffer: VkCommandBuffer) {
	frame_data := zr.get_current_frame_data(zr);;
	// Begin a render pass connected to our draw image
	clear_value : VkClearValue;
	clear_value.color._float32 = DEFAULT_CLEARVALUE;
	color_attachment : VkRenderingAttachmentInfo = vkinit_attachment_info(zr.draw_image.image_view, *clear_value, .VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL);

	depth_clear : VkClearValue;
	depth_clear.depthStencil.depth = 1.0;
	depth_attachment : VkRenderingAttachmentInfo = vkinit_depth_attachment_info(zr.depth_image.image_view, .VK_IMAGE_LAYOUT_DEPTH_ATTACHMENT_OPTIMAL);
	depth_attachment.loadOp = .VK_ATTACHMENT_LOAD_OP_CLEAR;
	depth_attachment.clearValue = depth_clear;

	render_info : VkRenderingInfo = vkinit_rendering_info(zr.draw_extent, *color_attachment, *depth_attachment);
	vkCmdBeginRendering(command_buffer, *render_info);
	{
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

		// Fetch this once per frame
		camera_data := cast,no_check(*Render_Camera.GPU_Camera_Data)frame_data.camera_buffer.info.pMappedData;
		<<camera_data = zr.camera.gpu_data;  // Just overwrite it each frame

		// Bind descriptor buffers before all draws
		bindings := VkDescriptorBufferBindingInfoEXT.[
			.{
				sType = .VK_STRUCTURE_TYPE_DESCRIPTOR_BUFFER_BINDING_INFO_EXT,
				address = zr.image_descriptor_buffer.base_address,
				usage = .VK_BUFFER_USAGE_RESOURCE_DESCRIPTOR_BUFFER_BIT_EXT,
			},
			.{
				sType = .VK_STRUCTURE_TYPE_DESCRIPTOR_BUFFER_BINDING_INFO_EXT,
				address = zr.sampler_descriptor_buffer.base_address,
				usage = .VK_BUFFER_USAGE_SAMPLER_DESCRIPTOR_BUFFER_BIT_EXT,
			},
		];
		vkCmdBindDescriptorBuffersEXT(command_buffer, 2, bindings.data);

		// Set descriptor buffer offsets (more weird Vulkan ways of doing things)
		buffer_indices : [2]u32 = .[0, 1];
		offsets : [2]VkDeviceSize = .[0, 0];
		vkCmdSetDescriptorBufferOffsetsEXT(command_buffer, .VK_PIPELINE_BIND_POINT_GRAPHICS,
			zr.opaque_material.layout,  // Any material's layout works they all use same descriptor layout
			0, 2, buffer_indices.data, offsets.data);
		
		// Generate the surface buckets (per material)
		frame_generate_surface_buckets(zr, scene);

		for bucket: zr.frame_surfaces.buckets {
			pipeline := bucket.material_pipeline;
			layout := bucket.material_pipeline_layout;
			if pipeline == VK_NULL_HANDLE {
				pipeline = zr.default_material.pipeline;
				print("Warning: No material found for mesh, defaulting to zr.default_material (this is slow)\n");
			}
		
			// Bind the pipeline for this material bucket
			vkCmdBindPipeline(command_buffer, .VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline);

			for t_surface: bucket.surfaces {
				index_offset := t_surface.surface.index_address - zr.geometry_pool.index_buffer.base_address;
				vkCmdBindIndexBuffer(command_buffer, zr.geometry_pool.index_buffer.buffer, index_offset, .VK_INDEX_TYPE_UINT32);
				
				push_constants : GPU_Draw_Push_Constants;
				push_constants.vertex_address = t_surface.surface.vertex_address;
				push_constants.transform_address = t_surface.transform_address;
				push_constants.material_address = t_surface.constants_address; // TODO: the whole material thing is broken sending zr.default material doesnt work either
				push_constants.camera_data_address = frame_data.camera_buffer.base_address;

				vkCmdPushConstants(command_buffer, layout, .VK_SHADER_STAGE_VERTEX_BIT | .VK_SHADER_STAGE_FRAGMENT_BIT, 0, size_of(GPU_Draw_Push_Constants), *push_constants);
				vkCmdDrawIndexed(command_buffer, t_surface.surface.index_count, 1, 0, 0, 0);
			}
		}
	}
	vkCmdEndRendering(command_buffer);
}


update_scene :: (zr: *ZRenderer) {
    // Build camera basis in  coordinate system
	using zr.camera;
    forward = rotate(AXIS_FORWARD, rotation);  // X-forward
    right   = rotate(AXIS_RIGHT, rotation);  // Y-right  
    up      = rotate(AXIS_UP, rotation);  // Z-up
    
	// Jai matrices are ROW MAJOR
    view_matrix := Matrix4.{
        right.x,    right.y,    right.z,    -dot(right, position),
        up.x,       up.y,       up.z,       -dot(up, position),
        -forward.x, -forward.y, -forward.z, dot(forward, position),
        0,          0,          0,          1
    };
    
    fov_radians := fov * PI / 180.0;
    aspect_ratio = cast(float)zr.draw_extent.width / cast(float)zr.draw_extent.height;
    
    proj_matrix := make_projection_matrix(
        fov_vertical = fov_radians,
        aspect_ratio_horizontal_over_vertical = aspect_ratio,
        z_near = near_plane,
        z_far = far_plane,
        depth_range_01 = true
    );
    proj_matrix._22 *= -1;
    
    gpu_data.view = view_matrix;
    gpu_data.proj = proj_matrix;
    gpu_data.view_proj = transpose(proj_matrix * view_matrix);
}

deinit_zrenderer :: (zr: *ZRenderer) {
	if zr.initialized {
		vkDeviceWaitIdle(zr.device); // Wait for it to finish whatever its doing

		for zr.swapchain_framebuffers {
			vkDestroyFramebuffer(zr.device, it, null);
		}
		destroy_swapchain(zr);

		vkDestroyPipelineLayout(zr.device, zr.pipeline_layout, null);

		vkDestroyRenderPass(zr.device, zr.render_pass, null);

		for zr.frames {
			vkDestroySemaphore(zr.device, it.swapchain_semaphore, null);
			vkDestroySemaphore(zr.device, it.render_semaphore, null);
			vkDestroyFence(zr.device, it.render_fence, null);
			vkDestroyCommandPool(zr.device, it.command_pool, null);

			it.deletion_queue.flush_deletion_queue(*it.deletion_queue);
		}

		GLOBAL_DELETION_QUEUE.flush_deletion_queue(*GLOBAL_DELETION_QUEUE);

		flush_images(zr);

		vmaDestroyAllocator(VMA_ALLOCATOR);

		vkDestroyDevice(zr.device, null);

		if ENABLE_VALIDATION_LAYERS {
			deinit_validation(zr, null);
		}

		vkDestroySurfaceKHR(zr.instance, zr.surface, null);
		
		vkDestroyInstance(zr.instance, null);
		
		SDL_DestroyWindow(zr.window);
	}
	SDL_Quit();
}

