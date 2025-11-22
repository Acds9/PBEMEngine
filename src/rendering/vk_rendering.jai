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

MATERIAL_INSTANCE_BUFFER_SIZE 	:: 16*1024*1024;
DRAW_COMMAND_BUFFER_SIZE		:: 4*1024*1024;
LIGHT_CLUSTER_BUFFER_SIZE		:: 1*1024*1024;

ZRenderer :: struct {
    // Core state
    initialized             : bool;
    frame_num              	: u32;
    do_render              	: bool;
    render_scale           	: float = 1;
    current_frame          	: u8;
	resolution				: VkExtent2D;
    
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

	// Textures
	image_table				: Table(string, Allocated_Image);

	default_sampler_nearest	: VkSampler;
	sampler_nearest_index	: u32 = 0;
	default_sampler_linear	: VkSampler;
	sampler_linear_index	: u32 = 1;

	material_instance_table	: Table(string, u32);

	mi_default				: u32;
	m_opaque				: Material_Pipeline_Opaque;

	material_instances		: Staged_Uniform_Storage_Buffer;

	default_clearvalue		: VkClearValue;

	render_globals			: Staged_Struct_Buffer;
	// Compute
	light_cluster_system	: Light_Cluster_System;
    
	Frame_Data :: struct {
		command_pool 				: VkCommandPool;
		command_buffer				: VkCommandBuffer;

		swapchain_semaphore 		: VkSemaphore;
		render_semaphore 			: VkSemaphore;
		render_fence				: VkFence;

		camera_buffer				: Allocated_Buffer;

		draw_commands_opaque			: Staged_Array_Buffer;
		draw_commands_transparent		: Staged_Array_Buffer;
		draw_commands_emissive			: Staged_Array_Buffer;
		draw_commands_debug_point		: Staged_Array_Buffer;
		draw_commands_debug_wireframe	: Staged_Array_Buffer;

		light_cluster_buffer			: Uniform_Storage_Buffer;

		deletion_queue				: Deletion_Queue;
	}

	debug_system : Debug_System;

    // Methods
    get_current_frame_data :: (using self: *ZRenderer) -> *Frame_Data {
        return *frames[current_frame];
    }
}

MATERIAL_PASS_COUNT	:: #run enum_names(MATERIAL_PASS).count;

Draw_Command_Point :: struct {
	draw 			: VkDrawIndirectCommand;
	data_address	: VkDeviceAddress;
	padding			: [4]u8;
}

Draw_Command :: struct {
	draw : VkDrawIndexedIndirectCommand;
	vertex_address      : VkDeviceAddress;
    transform_address   : VkDeviceAddress;
    material_instance   : u32;
    padding             : [4]u8;
}

generate_debug_draw_commands :: (zr: *ZRenderer, frame: *ZRenderer.Frame_Data, cmd: VkCommandBuffer) -> [DEBUG_SHAPE_COUNT]u32 {
	buffer_wireframe : *Staged_Array_Buffer = *frame.draw_commands_debug_wireframe;
	wireframe_draws := cast(*Draw_Command)buffer_wireframe.staging_buffer.info.pMappedData;
	buffer_wireframe.reset(buffer_wireframe);

	draw_counts : [DEBUG_SHAPE_COUNT]u32;

	debug_system := *zr.debug_system;
	debug_mesh_instances := *debug_system.mesh_instances;
	mapped_debug_meshes := cast,no_check(*Mesh_Instance)debug_mesh_instances.staging_buffer.info.pMappedData;
	
	for 0..debug_mesh_instances.count-1 {
		debug_mesh := *mapped_debug_meshes[it];

		for *surface: debug_mesh.mesh_asset.surfaces {
			material_instance_index : u32;
			if debug_mesh.material_overrides[it_index] < U32_MAX {
				material_instance_index = debug_mesh.material_overrides[it_index];
			}
			else {
				material_instance_index = surface.default_material_instance;
			}
			
			index_offset_bytes := surface.index_address - zr.geometry_pool.index_buffer.base_address;
            first_index := index_offset_bytes / size_of(u32); 

			command : VkDrawIndexedIndirectCommand;
			command.indexCount = surface.index_count;
			command.instanceCount = 1;
			command.firstIndex = xx,no_check first_index;
			command.vertexOffset = 0;
			command.firstInstance = 0;

			draw_command : Draw_Command; 
			draw_command.draw = command;
			draw_command.vertex_address = surface.vertex_address;
			draw_command.transform_address = debug_mesh.transform_address;
			draw_command.material_instance = material_instance_index;
			
			buffer_wireframe.allocate(buffer_wireframe, draw_command);
			draw_counts[DEBUG_SHAPE.MESH] += 1;
			
		}
	}

	buffer_wireframe.transfer(buffer_wireframe, cmd);

	return draw_counts;
}

generate_draw_commands :: (zr: *ZRenderer, scene: *ZScene, frame: *ZRenderer.Frame_Data, cmd: VkCommandBuffer) -> [MATERIAL_PASS_COUNT]u32 {
	buffer_opaque : *Staged_Array_Buffer = *frame.draw_commands_opaque;
	opaque_draws := cast(*Draw_Command)buffer_opaque.staging_buffer.info.pMappedData;
	buffer_opaque.reset(buffer_opaque);

	mesh_instances := *scene.mesh_instances;
	draw_counts : [MATERIAL_PASS_COUNT]u32;

	if scene.mesh_instances.count == 0
		return draw_counts;

	mapped_meshes := cast,no_check(*Mesh_Instance)mesh_instances.staging_buffer.info.pMappedData;
	material_data := cast,no_check(*Material_Instance)zr.material_instances.staging_buffer.info.pMappedData;
	for 0..scene.mesh_instances.count-1 {
		mesh := *mapped_meshes[it];
			
		// Skip if generation doesn't match
		if mesh.generation != mesh_instances.generations[it] {
			continue; 
		}

		for *surface: mesh.mesh_asset.surfaces {
			material_instance_index : u32;
			if mesh.material_overrides[it_index] < U32_MAX {
				material_instance_index = mesh.material_overrides[it_index];
			}
			else {
				material_instance_index = surface.default_material_instance;
			}
			material_instance_data	: *Material_Instance = *material_data[material_instance_index];

			index_offset_bytes := surface.index_address - zr.geometry_pool.index_buffer.base_address;
            first_index := index_offset_bytes / size_of(u32); 

			command : VkDrawIndexedIndirectCommand;
			command.indexCount = surface.index_count;
			command.instanceCount = 1;
			command.firstIndex = xx,no_check first_index;
			command.vertexOffset = 0;
			command.firstInstance = 0;

			draw_command : Draw_Command; 
			draw_command.draw = command;
			draw_command.vertex_address = surface.vertex_address;
			draw_command.transform_address = mesh.transform_address;
			draw_command.material_instance = material_instance_index;

			if material_instance_data.pass == {
				case .OPAQUE; {
					buffer_opaque.allocate(buffer_opaque, draw_command);
					draw_counts[MATERIAL_PASS.OPAQUE] += 1;
				}
			} 
		}
	}


	buffer_opaque.transfer(buffer_opaque, cmd);

	
	return draw_counts;
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

	zr.light_cluster_system.init(*zr.light_cluster_system, zr, zr.resolution); // This needs to be re-initialized upon resolution changes?

	zr.debug_system = create_debug_system(VMA_ALLOCATOR, zr.device);

	zr.render_globals = make_staged_struct_buffer(VMA_ALLOCATOR, size_of(Render_Globals), .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, zr.device, "render globals buffer");
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, *zr.render_globals);
	rg := Render_Globals.{zr.swapchain_extent.width, zr.swapchain_extent.height, LIGHT_CLUSTER_NUM_WIDTH, LIGHT_CLUSTER_NUM_HEIGHT, LIGHT_CLUSTER_NUM_DEPTH, NEAR_PLANE, FAR_PLANE};
	zr.render_globals.allocate(*zr.render_globals, rg);

	success, error = init_commands(zr);
	if !success return false, error;
	success, error = init_pipelines(zr);
	if !success return false, error;

	fp.init(*zr.mesh_pool);
	allocator := Allocator.{fp.flat_pool_allocator_proc, *zr.mesh_pool};
	zr.meshes.allocator = allocator;

	zr.geometry_pool.init(*zr.geometry_pool, zr.device, VMA_ALLOCATOR, GEOPOOL_VERTEX_ALLOC_SIZE, GEOPOOL_INDEX_ALLOC_SIZE);
	// TODO: need to load all meshes
	
	

	generate_default_images(zr);
	create_default_samplers(zr);
	create_default_materials(zr);
	
	init_camera(*zr.camera);

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
	zr.material_instances = make_staged_uniform_storage_buffer(VMA_ALLOCATOR, MATERIAL_INSTANCE_BUFFER_SIZE, size_of(Material_Instance), .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, zr.device, "material_instance buffer");
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, *zr.material_instances);
	
	zr.debug_system.m_debug_point.build(*zr.debug_system.m_debug_point, zr);
	zr.debug_system.m_debug_wireframe.build(*zr.debug_system.m_debug_wireframe, zr);
	zr.m_opaque.build(*zr.m_opaque, zr);
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

		frame.draw_commands_opaque = make_staged_array_buffer(VMA_ALLOCATOR, DRAW_COMMAND_BUFFER_SIZE, size_of(Draw_Command), .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT | .VK_BUFFER_USAGE_INDIRECT_BUFFER_BIT, 
																	zr.device, sprint("frame % draw commands opaque buffer", it_index));
		queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, *frame.draw_commands_opaque);

		frame.draw_commands_transparent = make_staged_array_buffer(VMA_ALLOCATOR, DRAW_COMMAND_BUFFER_SIZE, size_of(Draw_Command), .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT | .VK_BUFFER_USAGE_INDIRECT_BUFFER_BIT, 
																	zr.device, sprint("frame % draw commands transparent buffer", it_index));
		queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, *frame.draw_commands_transparent);

		frame.draw_commands_emissive = make_staged_array_buffer(VMA_ALLOCATOR, DRAW_COMMAND_BUFFER_SIZE, size_of(Draw_Command), .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT | .VK_BUFFER_USAGE_INDIRECT_BUFFER_BIT, 
																	zr.device, sprint("frame % draw commands emissive buffer", it_index));
		queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, *frame.draw_commands_emissive);

		frame.draw_commands_debug_point = make_staged_array_buffer(VMA_ALLOCATOR, DRAW_COMMAND_BUFFER_SIZE, size_of(Draw_Command), .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT | .VK_BUFFER_USAGE_INDIRECT_BUFFER_BIT, 
																	zr.device, sprint("frame % draw commands point buffer", it_index));
		queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, *frame.draw_commands_debug_point);

		frame.draw_commands_debug_wireframe = make_staged_array_buffer(VMA_ALLOCATOR, DRAW_COMMAND_BUFFER_SIZE, size_of(Draw_Command), .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT | .VK_BUFFER_USAGE_INDIRECT_BUFFER_BIT, 
																	zr.device, sprint("frame % draw commands wireframe buffer", it_index));
		queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, *frame.draw_commands_debug_wireframe);
	}
}

draw_frame :: (zr: *ZRenderer, scene: *ZScene) {
	if zr.swapchain_extent.width == 0 || zr.swapchain_extent.height == 0 {
        return;
    }
	update_scene(zr);

	frame_data := zr.get_current_frame_data(zr);
	cmd := frame_data.command_buffer;
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
	vkResetCommandBuffer(cmd, 0);

	// Set the draw image extents to match the swapchain
	zr.draw_extent.height = cast,no_check(u32)(min(zr.swapchain_extent.height, zr.draw_image.image_extent.height) * zr.render_scale);
	zr.draw_extent.width = cast,no_check(u32)(min(zr.swapchain_extent.width, zr.draw_image.image_extent.width) * zr.render_scale);

	begin_info := vkinit_command_buffer_begin_info();

	// Begin the command buffer to record commands, everything after this is command recording
    vkBeginCommandBuffer(cmd, *begin_info);
	{
		// Copy the staging buffers right at the start
		transfer_buffers(zr, scene, cmd);

		debug_draw_counts := generate_debug_draw_commands(zr, frame_data, cmd);
		draw_counts := generate_draw_commands(zr, scene, frame_data, cmd);

		cluster_buffer := zr.light_cluster_system.get_frame_buffer(*zr.light_cluster_system, zr.current_frame);
		light_bitfield := zr.light_cluster_system.get_frame_light_bitfield(*zr.light_cluster_system, zr.current_frame);

		// Zero the buffers/bitfields
		vkCmdFillBuffer(cmd, cluster_buffer.buffer, 0, cluster_buffer.info.size, 0);
		vkCmdFillBuffer(cmd, light_bitfield.buffer, 0, light_bitfield.info.size, 0);

		// Barrier to make sure the zeroing is done
		barrier := VkMemoryBarrier.{
			sType = .VK_STRUCTURE_TYPE_MEMORY_BARRIER,
			srcAccessMask = .VK_ACCESS_TRANSFER_WRITE_BIT,
			dstAccessMask = .VK_ACCESS_SHADER_READ_BIT | .VK_ACCESS_SHADER_WRITE_BIT,
		};
		vkCmdPipelineBarrier(cmd, .VK_PIPELINE_STAGE_TRANSFER_BIT, .VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 1, *barrier, 0, null, 0, null);

		// Buffers ready, ready to start compute, move this stuff to a function

		// LIGHT CULLING 
		vkCmdBindPipeline(cmd, .COMPUTE, zr.light_cluster_system.m_c_light_culling.pipeline);
		light_cull_push: Light_Culling_Push_Constants;
		light_cull_push.bda_render_globals = zr.render_globals.device_buffer.base_address;
		light_cull_push.bda_camera = frame_data.camera_buffer.base_address;
		light_cull_push.bda_point_lights = scene.point_lights.device_buffer.base_address;
		light_cull_push.bda_light_bitfield = light_bitfield.base_address;
		light_cull_push.point_light_count = scene.point_lights.count;
	
		vkCmdPushConstants(cmd, 
						zr.light_cluster_system.m_c_light_culling.layout,
						.VK_SHADER_STAGE_COMPUTE_BIT,
						0,
						size_of(Light_Culling_Push_Constants),
						*light_cull_push);

		light_cull_x : u32 = 64;
		light_cull_y : u32 = 1; 
		light_cull_z : u32 = 1;
		vkCmdDispatch(cmd, light_cull_x, light_cull_y, light_cull_z);

		// Barrier to ensure we don't light cluster before culling is done
		light_cull_barrier : VkBufferMemoryBarrier2;
		light_cull_barrier = .{
			srcStageMask = VK_PIPELINE_STAGE_2_COMPUTE_SHADER_BIT,
			srcAccessMask = VK_ACCESS_2_SHADER_STORAGE_WRITE_BIT,
			dstStageMask = VK_PIPELINE_STAGE_2_COMPUTE_SHADER_BIT,
			dstAccessMask = VK_ACCESS_2_SHADER_STORAGE_READ_BIT,
			srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
			dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
			buffer = light_bitfield.buffer,
			offset = 0,
			size = VK_WHOLE_SIZE,
		};

		light_cull_dependency := VkDependencyInfo.{
			bufferMemoryBarrierCount = 1,
			pBufferMemoryBarriers = *light_cull_barrier,
		};

		vkCmdPipelineBarrier2(cmd, *light_cull_dependency);

		// Now do light clustering
		vkCmdBindPipeline(cmd, .COMPUTE, zr.light_cluster_system.m_c_light_cluster.pipeline);

		light_cluster_push: Light_Clustering_Push_Constants;
		light_cluster_push.bda_render_globals = zr.render_globals.device_buffer.base_address;
		light_cluster_push.bda_camera = frame_data.camera_buffer.base_address;
		light_cluster_push.bda_point_lights = scene.point_lights.device_buffer.base_address;
		light_cluster_push.bda_clusters = cluster_buffer.base_address;
		light_cluster_push.bda_light_bitfield = light_bitfield.base_address;
		light_cluster_push.point_light_count = scene.point_lights.count;
	
		vkCmdPushConstants(cmd, 
						zr.light_cluster_system.m_c_light_cluster.layout,
						.VK_SHADER_STAGE_COMPUTE_BIT,
						0,
						size_of(Light_Clustering_Push_Constants),
						*light_cluster_push);


		// Divide by the layout local size in the shader
		light_cluster_x : u32 = LIGHT_CLUSTER_NUM_WIDTH/8;
		light_cluster_y : u32 = LIGHT_CLUSTER_NUM_HEIGHT/8; 
		light_cluster_z : u32 = LIGHT_CLUSTER_NUM_DEPTH/1;
		vkCmdDispatch(cmd, light_cluster_x, light_cluster_y, light_cluster_z);

		buffer_barriers: [1] VkBufferMemoryBarrier2;
		/*
		// Barrier 1: Culled draw commands (compute write -> indirect read)
		buffer_barriers[0] = .{
			srcStageMask = .COMPUTE_SHADER_BIT,
			srcAccessMask = .SHADER_STORAGE_WRITE_BIT,
			dstStageMask = .DRAW_INDIRECT_BIT,
			dstAccessMask = .INDIRECT_COMMAND_READ_BIT,
			srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
			dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
			buffer = indirect_draw_buffer.handle,
			offset = 0,
			size = VK_WHOLE_SIZE,
		};
		*/
		// Barrier 2: Cluster data (compute write -> fragment shader read)
		buffer_barriers[0] = .{
			srcStageMask = VK_PIPELINE_STAGE_2_COMPUTE_SHADER_BIT,
			srcAccessMask = VK_ACCESS_2_SHADER_STORAGE_WRITE_BIT,
			dstStageMask = VK_PIPELINE_STAGE_2_FRAGMENT_SHADER_BIT,
			dstAccessMask = VK_ACCESS_2_SHADER_STORAGE_READ_BIT,
			srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
			dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
			buffer = cluster_buffer.buffer,
			offset = 0,
			size = VK_WHOLE_SIZE,
		};

		dependency := VkDependencyInfo.{
			bufferMemoryBarrierCount = buffer_barriers.count,
			pBufferMemoryBarriers = buffer_barriers.data,
		};

		vkCmdPipelineBarrier2(cmd, *dependency);

		// Transition main draw image (and depth image) into general layout so we can draw into it
		vkutil_transition_image(cmd, zr.draw_image.image, .VK_IMAGE_LAYOUT_UNDEFINED, .VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL, .VK_IMAGE_ASPECT_COLOR_BIT);
		vkutil_transition_image(cmd, zr.depth_image.image, .VK_IMAGE_LAYOUT_UNDEFINED, .VK_IMAGE_LAYOUT_DEPTH_ATTACHMENT_OPTIMAL, .VK_IMAGE_ASPECT_DEPTH_BIT);

		clear_value : VkClearValue;
		clear_value.color._float32 = DEFAULT_CLEARVALUE;
		color_attachment : VkRenderingAttachmentInfo = vkinit_attachment_info(zr.draw_image.image_view, *clear_value, .VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL);

		depth_clear : VkClearValue;
		depth_clear.depthStencil.depth = 0.0;
		depth_attachment : VkRenderingAttachmentInfo = vkinit_depth_attachment_info(zr.depth_image.image_view, .VK_IMAGE_LAYOUT_DEPTH_ATTACHMENT_OPTIMAL);
		depth_attachment.loadOp = .VK_ATTACHMENT_LOAD_OP_CLEAR;
		depth_attachment.clearValue = depth_clear;

		render_info : VkRenderingInfo = vkinit_rendering_info(zr.draw_extent, *color_attachment, *depth_attachment);

		vkCmdBeginRendering(cmd, *render_info);
		{
			execute_debug_draw(zr, cmd, debug_draw_counts);
			execute_draw(zr, scene, cmd, draw_counts);
		}
		vkCmdEndRendering(cmd);

		// Transition the draw image to be copied FROM
		vkutil_transition_image(cmd, zr.draw_image.image, .VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL, .VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, .VK_IMAGE_ASPECT_COLOR_BIT);
		// Transition the swapchain image to be copied INTO
		vkutil_transition_image(cmd, zr.swapchain_images[image_idx], .VK_IMAGE_LAYOUT_UNDEFINED, .VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, .VK_IMAGE_ASPECT_COLOR_BIT);

		// Execute a copy from the draw image into the swapchain with blitting
		vkutil_blit_copy_image_image(cmd, zr.draw_image.image, zr.swapchain_images[image_idx], zr.draw_extent, zr.swapchain_extent);

		// Set the swapchain image layout to be presented to the surface (AKA the window)
		vkutil_transition_image(cmd, zr.swapchain_images[image_idx], .VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, .VK_IMAGE_LAYOUT_PRESENT_SRC_KHR, .VK_IMAGE_ASPECT_COLOR_BIT);
	}
	// End command recording to this buffer
	vkEndCommandBuffer(cmd);

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
	command_buffer_submit_info.commandBuffer = cmd;
	command_buffer_submit_info.deviceMask = 0;

	submit_info.commandBufferInfoCount = 1;
	submit_info.pCommandBufferInfos = *command_buffer_submit_info;

	// Actually submit the command buffer for the GPU to start working on
	result := vkQueueSubmit2(zr.graphics_queue, 1, *submit_info, frame_data.render_fence);
	if result != .VK_SUCCESS {
		print("%\n", result);
		vkResetCommandBuffer(cmd, 0);
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

transfer_buffers :: (zr: *ZRenderer, scene: *ZScene, cmd: VkCommandBuffer) {
	zr.material_instances.transfer(*zr.material_instances, cmd);
	zr.debug_system.transfer(*zr.debug_system, cmd);
	zr.render_globals.transfer(*zr.render_globals, cmd);
	
	scene.mesh_instances.transfer(*scene.mesh_instances, cmd);
	scene.mesh_transforms.transfer(*scene.mesh_transforms, cmd);
	scene.point_lights.transfer(*scene.point_lights, cmd);
	
	// Barrier to ensure copies complete before rendering
    barrier : VkMemoryBarrier;
    barrier.sType = .VK_STRUCTURE_TYPE_MEMORY_BARRIER;
    barrier.srcAccessMask = .VK_ACCESS_TRANSFER_WRITE_BIT;
    barrier.dstAccessMask = .VK_ACCESS_SHADER_READ_BIT;
    
    vkCmdPipelineBarrier(cmd, .VK_PIPELINE_STAGE_TRANSFER_BIT, .VK_PIPELINE_STAGE_ALL_GRAPHICS_BIT , 0, 1, *barrier, 0, null, 0, null);
}

execute_draw :: (zr: *ZRenderer, scene: *ZScene, command_buffer: VkCommandBuffer, draw_counts: []u32) {
	frame_data := zr.get_current_frame_data(zr);
	
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
		zr.m_opaque.layout,  // Any material's layout works they all use same descriptor layout
		0, 2, buffer_indices.data, offsets.data);


	vkCmdBindIndexBuffer(command_buffer, zr.geometry_pool.index_buffer.buffer, 0, .VK_INDEX_TYPE_UINT32);

	if draw_counts[MATERIAL_PASS.OPAQUE] > 0 {
		vkCmdBindPipeline(command_buffer, .VK_PIPELINE_BIND_POINT_GRAPHICS, zr.m_opaque.pipeline);

		light_cluster_buffer := zr.light_cluster_system.get_frame_buffer(*zr.light_cluster_system, zr.current_frame);

		push : Draw_Push_Constants;
		push.render_globals = zr.render_globals.device_buffer.base_address;
        push.draw_address = frame_data.draw_commands_opaque.device_buffer.base_address;
        push.camera_data_address = frame_data.camera_buffer.base_address;
        push.material_address = zr.material_instances.device_buffer.base_address;
		push.cluster_index_address = light_cluster_buffer.base_address;
		push.point_lights_address = scene.point_lights.device_buffer.base_address;
		push.point_lights_count = scene.point_lights.count;

        vkCmdPushConstants(command_buffer, zr.m_opaque.layout, .VK_SHADER_STAGE_VERTEX_BIT | .VK_SHADER_STAGE_FRAGMENT_BIT, 0, size_of(Draw_Push_Constants), *push);

		vkCmdDrawIndexedIndirect(command_buffer, frame_data.draw_commands_opaque.device_buffer.buffer, 0, draw_counts[MATERIAL_PASS.OPAQUE], size_of(Draw_Command));
	}
}

execute_debug_draw :: (zr: *ZRenderer, command_buffer: VkCommandBuffer, draw_counts: []u32) {
	// It's fine to duplicate this as it's just debug stuff
	frame_data := zr.get_current_frame_data(zr);
	debug_system := *zr.debug_system;
	
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

	camera_data := cast,no_check(*Render_Camera.GPU_Camera_Data)frame_data.camera_buffer.info.pMappedData;
	<<camera_data = zr.camera.gpu_data; 

	vkCmdBindIndexBuffer(command_buffer, zr.geometry_pool.index_buffer.buffer, 0, .VK_INDEX_TYPE_UINT32);
	
	if draw_counts[DEBUG_SHAPE.MESH] > 0 {
		push : Draw_Push_Constants;
		push.render_globals = zr.render_globals.device_buffer.base_address;
        push.draw_address = frame_data.draw_commands_debug_wireframe.device_buffer.base_address;
        push.camera_data_address = frame_data.camera_buffer.base_address;
        push.material_address = debug_system.mesh_material_instances.device_buffer.base_address;
        
        vkCmdPushConstants(command_buffer, zr.debug_system.m_debug_wireframe.layout, .VK_SHADER_STAGE_VERTEX_BIT | .VK_SHADER_STAGE_FRAGMENT_BIT, 0, size_of(Draw_Push_Constants), *push);

        vkCmdBindPipeline(command_buffer, .VK_PIPELINE_BIND_POINT_GRAPHICS, zr.debug_system.m_debug_wireframe.pipeline);
        vkCmdDrawIndexedIndirect(command_buffer, frame_data.draw_commands_debug_wireframe.device_buffer.buffer, 0, draw_counts[DEBUG_SHAPE.MESH], size_of(Draw_Command));
    }
	
	point_instances := *zr.debug_system.point_instances;
	if point_instances.count > 0 {
		push : Debug_Draw_Push_Constants;
		push.render_globals = zr.render_globals.device_buffer.base_address;
		push.vertex_address = point_instances.device_buffer.base_address;
		push.camera_data_address = frame_data.camera_buffer.base_address;
		vkCmdPushConstants(command_buffer, zr.debug_system.m_debug_point.layout, .VK_SHADER_STAGE_VERTEX_BIT | .VK_SHADER_STAGE_FRAGMENT_BIT, 0, size_of(Debug_Draw_Push_Constants), *push);

		vkCmdBindPipeline(command_buffer, .VK_PIPELINE_BIND_POINT_GRAPHICS, zr.debug_system.m_debug_point.pipeline);
		vkCmdDraw(command_buffer, point_instances.count, 1, 0, 0);
	}
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
        z_near = far_plane, // Inverted depth
        z_far = near_plane,
        depth_range_01 = true
    );
    proj_matrix._22 *= -1;

	gpu_data.view = transpose(view_matrix);
    gpu_data.proj = transpose(proj_matrix);
    gpu_data.view_proj = proj_matrix * view_matrix;

	using gpu_data.view_proj;
	gpu_data.view_planes[0] = Vector4.{_41, _42, _43, _44} + Vector4.{_11, _12, _13, _14};
	gpu_data.view_planes[1] = Vector4.{_41, _42, _43, _44} - Vector4.{_11, _12, _13, _14};
	gpu_data.view_planes[2] = Vector4.{_41, _42, _43, _44} + Vector4.{_21, _22, _23, _24};
	gpu_data.view_planes[3] = Vector4.{_41, _42, _43, _44} - Vector4.{_21, _22, _23, _24};
	gpu_data.view_planes[4] = Vector4.{_41, _42, _43, _44} + Vector4.{_31, _32, _33, _34};
	gpu_data.view_planes[5] = Vector4.{_41, _42, _43, _44} - Vector4.{_31, _32, _33, _34};

	for *plane: gpu_data.view_planes {
		<<plane = normalize(<<plane);
	}
    
	// Transpose AFTER plane calculation
    gpu_data.view_proj = transpose(gpu_data.view_proj);

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

