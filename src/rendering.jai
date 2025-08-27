#import "Basic";
#import "Math";
#import "SDL";
#import "Vulkan";

Required_Extensions :: (*u8).[
    "VK_EXT_debug_utils",
];

Required_Device_Extensions :: (*u8).[
	VK_KHR_SWAPCHAIN_EXTENSION_NAME,
];

Desired_Validation_Layers :: (*u8).[
    "VK_LAYER_KHRONOS_validation",
];

Queue_Family_Indices :: struct {
	graphics : s32 = -1;  // -1 means not found
    present  : s32 = -1;
    compute  : s32 = -1;
    transfer : s32 = -1;

	is_complete :: (using self: Queue_Family_Indices) -> bool {
        return graphics > -1 && present > -1;
    }
}

Swapchain_Support_Details :: struct {
	capabilities 	: VkSurfaceCapabilitiesKHR;
	formats			: [..]VkSurfaceFormatKHR;
	present_modes	: [..]VkPresentModeKHR;
}

ENABLE_VALIDATION_LAYERS :: true;

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

	queue_indices			: Queue_Family_Indices;
	graphics_queue			: VkQueue;
	present_queue			: VkQueue;

	render_pass 			: VkRenderPass;
	pipeline_layout			: VkPipelineLayout;

	graphics_pipeline		: VkPipeline;

	swapchain_framebuffers	: [..]VkFramebuffer;

	command_pool 			: VkCommandPool;
	command_buffer			: VkCommandBuffer;

	image_available_semaphore 	: VkSemaphore;
	render_finished_semaphore 	: VkSemaphore;
	in_flight_fence				: VkFence;
}

init_instance :: (zr: *ZRenderer) -> bool, string {
	app_info : VkApplicationInfo;
	app_info.sType = .VK_STRUCTURE_TYPE_APPLICATION_INFO;
	app_info.pApplicationName = "ZRenderer";
	app_info.applicationVersion = VK_MAKE_VERSION(1,0,0);
	app_info.pEngineName = "ZEngine";
	app_info.engineVersion = VK_MAKE_VERSION(1,0,0);
	app_info.apiVersion = VK_API_VERSION_1_3;

	create_info : VkInstanceCreateInfo;
	create_info.sType = .VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
	create_info.pApplicationInfo = *app_info;

	// EXTENSIONS
	SDL_Vulkan_GetInstanceExtensions :: (window : *SDL_Window, num_extensions : *u32, extensions : **u8) -> SDL_bool #foreign SDL2;

	num_extensions 			: u32;
	required_extensions		: [..]*u8;
	
	SDL_Vulkan_GetInstanceExtensions(zr.window, *num_extensions, null);
	array_resize(*required_extensions, num_extensions);

    SDL_Vulkan_GetInstanceExtensions(zr.window, *num_extensions, required_extensions.data);

    for Required_Extensions {
        array_add(*required_extensions, it);
    }
	if ENABLE_VALIDATION_LAYERS array_add(*required_extensions, VK_EXT_DEBUG_UTILS_EXTENSION_NAME);

	// Check which are actually supported
	vkEnumerateInstanceExtensionProperties(null, *num_extensions, null);
	supported_extensions : [..]VkExtensionProperties;
	array_resize(*supported_extensions, num_extensions);
	vkEnumerateInstanceExtensionProperties(null, *num_extensions, supported_extensions.data);

	unsupported_extensions : [..]string;
	for req: required_extensions {
		supported : bool;
		for supp: supported_extensions {
			if to_string(req) == to_string(supp.extensionName.data) {
				supported = true;
				break supp;
			}
		}
		if !supported array_add(*unsupported_extensions, to_string(req));
	}
	if unsupported_extensions.count print("WARNING: The following Vulkan extensions are unsupported: %\n", unsupported_extensions);

	// VALIDATION LAYERS
	layer_count : u32;
	vkEnumerateInstanceLayerProperties(*layer_count, null);

	supported_layers : [..]VkLayerProperties;
	array_resize(*supported_layers, layer_count);

	vkEnumerateInstanceLayerProperties(*layer_count, supported_layers.data);

	unsupported_layers : [..]string;
	for des: Desired_Validation_Layers {
		supported : bool;
		for supp: supported_layers {
			if to_string(supp.layerName.data) == to_string(des) {
				supported = true;
				break supp;
			}
		}
		if !supported array_add(*unsupported_layers, to_string(des));
	}
	if unsupported_layers.count print("WARNING: The following Vulkan validation layers are unsupported: %\n", unsupported_layers);

	// INSTANCE CREATION
	SDL_Vulkan_GetInstanceExtensions(zr.window, *num_extensions, required_extensions.data);
	create_info.enabledExtensionCount = cast,no_check(u32)required_extensions.count;
	create_info.ppEnabledExtensionNames = required_extensions.data;
	
	if ENABLE_VALIDATION_LAYERS {
		create_info.enabledLayerCount = cast,no_check(u32)Desired_Validation_Layers.count;
		create_info.ppEnabledLayerNames = Desired_Validation_Layers.data;
	} else create_info.enabledLayerCount = 0;

	result := vkCreateInstance(*create_info, null, *zr.instance);
	if result != .VK_SUCCESS {
		return false, "Error creating Vk instance";
	}
	return true, "";
}

init_validation :: (zr: *ZRenderer) -> bool, string {
	debug_info : VkDebugUtilsMessengerCreateInfoEXT;
	debug_info.sType			= .VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT;
    debug_info.messageSeverity 	= .VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT | .VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT  | .VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT | .VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT ;
    debug_info.messageType 		= .VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT  | .VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT  | .VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT;
    debug_info.pfnUserCallback 	= VulkanDebugCallback;
    debug_info.pUserData 		= *context;

	PFN_vkCreateDebugUtilsMessengerEXT :: #type (instance: VkInstance, pCreateInfo: *VkDebugUtilsMessengerCreateInfoEXT, pAllocator: *VkAllocationCallbacks, pDebugMessenger: *VkDebugUtilsMessengerEXT) -> VkResult #c_call;
	func := cast(PFN_vkCreateDebugUtilsMessengerEXT) vkGetInstanceProcAddr(zr.instance, "vkCreateDebugUtilsMessengerEXT");

	if func {
        result := func(zr.instance, *debug_info, null, *zr.debug_messenger);
		if result == .VK_SUCCESS {return true, "";}
		else return false, sprint("%\n", result);
    } else {
        return false, sprint("%\n", VkResult.VK_ERROR_EXTENSION_NOT_PRESENT);
    }
}

deinit_validation :: (zr: *ZRenderer, alloc: *VkAllocationCallbacks) {
	PFN_vkDestroyDebugUtilsMessengerEXT :: #type (instance: VkInstance, messenger: VkDebugUtilsMessengerEXT, pAllocator: *VkAllocationCallbacks) #c_call;
	func := cast(PFN_vkDestroyDebugUtilsMessengerEXT) vkGetInstanceProcAddr(zr.instance, "vkDestroyDebugUtilsMessengerEXT");
	if func {
    	func(zr.instance, zr.debug_messenger, null);
    }
}

VulkanDebugCallback :: (severity : VkDebugUtilsMessageSeverityFlagBitsEXT, type : VkDebugUtilsMessageTypeFlagsEXT, callback_data : *VkDebugUtilsMessengerCallbackDataEXT, user_data : *void) 
					-> VkBool32 #c_call {
											if callback_data.messageIdNumber == {
											case 0xc81ad50e; // WARNING-Shader-OutputNotConsumed
												return VK_FALSE;
											}
	ctx := cast(*#Context, user_data).*;
    push_context,defer_pop ctx;

    msg := to_string(callback_data.pMessage);

    if severity & .VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT {
        print("ERROR (VK): %\n", msg);
    } else if severity & .VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT {
        print("WARNING (VK): %\n", msg);
    } else {
        print("MESSAGE (VK): %\n%", msg);
    }

    return VK_FALSE;
}

create_surface :: (zr: *ZRenderer) -> bool, string {

	SDL_Vulkan_CreateSurface :: (window : *SDL_Window, instance : VkInstance, surface : *VkSurfaceKHR) -> SDL_bool #foreign SDL2;

	result := SDL_Vulkan_CreateSurface(zr.window, zr.instance, *zr.surface);
	if !result return false, "Could not creat Vk Surface";
	return true, "";
}

select_physical_device :: (zr: *ZRenderer) -> bool, string {
	device_count : u32;
	vkEnumeratePhysicalDevices(zr.instance, *device_count, null);
	if !device_count return false, "ERROR: Failed to find physical devices with Vulkan support.";
	
	physical_devices : [..]VkPhysicalDevice;
	array_resize(*physical_devices, device_count);
	vkEnumeratePhysicalDevices(zr.instance, *device_count, physical_devices.data);
	
	selected_physical_device : VkPhysicalDevice;
	for dev: physical_devices {
		device_properties 	: VkPhysicalDeviceProperties;
		vkGetPhysicalDeviceProperties(dev, *device_properties);
		device_features		: VkPhysicalDeviceFeatures;
		vkGetPhysicalDeviceFeatures(dev, *device_features);
		
		if device_properties.deviceType == .VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU  && device_features.geometryShader {
			selected_physical_device = dev;
			print("Using physical device: %\n", to_string(device_properties.deviceName.data));
			break dev;
		}
	}
	if !selected_physical_device return false, "ERROR: No suitable physical device found";
	zr.physical_device = selected_physical_device;

	// QUEUES
	queue_family_count : u32;
	vkGetPhysicalDeviceQueueFamilyProperties(selected_physical_device, *queue_family_count, null);
	queue_families : [..]VkQueueFamilyProperties;
	array_resize(*queue_families, queue_family_count);
	vkGetPhysicalDeviceQueueFamilyProperties(selected_physical_device, *queue_family_count, queue_families.data);
	
	for queue_families {
		if it.queueFlags & .VK_QUEUE_GRAPHICS_BIT && zr.queue_indices.graphics < 0 {
            zr.queue_indices.graphics = cast,no_check(s32)it_index;
        }

		present_support : u32;
		vkGetPhysicalDeviceSurfaceSupportKHR(zr.physical_device, cast,no_check(u32)it_index, zr.surface, *present_support);
		if present_support && zr.queue_indices.present < 0 {
            zr.queue_indices.present = cast,no_check(s32)it_index;
        }
	}

	if !zr.queue_indices.is_complete(zr.queue_indices)
		return false, "ERROR: No queue families found";
	if !query_extension_support(zr) 
		return false, "ERROR: Not all required device extensions are supported\n";
	if !query_swapchain_support(zr)
		return false, "ERROR: Swapchain support insufficient";

	return true, "";
}

query_extension_support :: (zr: *ZRenderer) -> bool {
	device_extensions : [..]*u8;
		for Required_Device_Extensions {
		array_add(*device_extensions, it);
	}

	extension_count : u32;
	vkEnumerateDeviceExtensionProperties(zr.physical_device, null, *extension_count, null);

	available_extensions : [..]VkExtensionProperties;
	array_resize(*available_extensions, extension_count);
	vkEnumerateDeviceExtensionProperties(zr.physical_device, null, *extension_count, available_extensions.data);

	found_extensions := 0;
	for req: device_extensions {
		for avail: available_extensions {
			if to_string(avail.extensionName.data) == to_string(req) {
				found_extensions += 1;
				break avail;
			} 
		}
	}
	if found_extensions != device_extensions.count 
		return false;

	return true;
}

query_swapchain_support :: (zr: *ZRenderer) -> bool {
	vkGetPhysicalDeviceSurfaceCapabilitiesKHR(zr.physical_device, zr.surface, *zr.swapchain_details.capabilities);
	
	format_count : u32;
	vkGetPhysicalDeviceSurfaceFormatsKHR(zr.physical_device, zr.surface, *format_count, null);
	array_resize(*zr.swapchain_details.formats, format_count);
	vkGetPhysicalDeviceSurfaceFormatsKHR(zr.physical_device, zr.surface, *format_count, zr.swapchain_details.formats.data);
	
	present_mode_count : u32;
	vkGetPhysicalDeviceSurfacePresentModesKHR(zr.physical_device, zr.surface, *present_mode_count, null);
	array_resize(*zr.swapchain_details.present_modes, present_mode_count);
	vkGetPhysicalDeviceSurfacePresentModesKHR(zr.physical_device, zr.surface, *present_mode_count, zr.swapchain_details.present_modes.data);

	if !zr.swapchain_details.formats.count || !zr.swapchain_details.present_modes.count 
		return false;

	return true;
}

create_logical_device :: (zr: *ZRenderer) -> bool, string {
	queue_create_infos 	: [..]VkDeviceQueueCreateInfo;
	queue_families		: [..]s32;
	array_add_unique(*queue_families, zr.queue_indices.graphics);
	array_add_unique(*queue_families, zr.queue_indices.present);
	
	queue_priority : float = 1;
	for queue_families {
		queue_create_info : VkDeviceQueueCreateInfo;
		queue_create_info.sType = .VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
		queue_create_info.queueFamilyIndex = cast,no_check(u32)it;
		queue_create_info.queueCount = 1;
		queue_create_info.pQueuePriorities = *queue_priority;
		array_add(*queue_create_infos, queue_create_info);
	}
	device_features : VkPhysicalDeviceFeatures;

	device_create_info : VkDeviceCreateInfo;
	device_create_info.sType = .VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
	device_create_info.queueCreateInfoCount = xx queue_create_infos.count;
	device_create_info.pQueueCreateInfos = queue_create_infos.data;
	device_create_info.pEnabledFeatures = *device_features;
	device_create_info.enabledExtensionCount = Required_Device_Extensions.count;
	device_create_info.ppEnabledExtensionNames = Required_Device_Extensions.data;

	if ENABLE_VALIDATION_LAYERS {
		device_create_info.enabledLayerCount = Desired_Validation_Layers.count;
		device_create_info.ppEnabledLayerNames = Desired_Validation_Layers.data;
	} else device_create_info.enabledLayerCount = 0;

	result := vkCreateDevice(zr.physical_device, *device_create_info, null, *zr.logical_device);
	
	vkGetDeviceQueue(zr.logical_device, cast,no_check(u32)zr.queue_indices.graphics, 0, *zr.graphics_queue);
	if zr.queue_indices.present != zr.queue_indices.graphics {
    	vkGetDeviceQueue(zr.logical_device, cast,no_check(u32)zr.queue_indices.present, 0, *zr.present_queue);
	} else {
		zr.present_queue = zr.graphics_queue; 
	}
	if result == .VK_SUCCESS {return true, "";}
	else return false, sprint("%\n", result);
}


init_swapchain :: (zr: *ZRenderer) -> bool, string {
	
	// FORMAT
	available_formats := zr.swapchain_details.formats;
	chosen_format : VkSurfaceFormatKHR;
	found_format : bool;
	for available_formats {
		if it.format == .VK_FORMAT_B8G8R8A8_SRGB && it.colorSpace == .VK_COLOR_SPACE_SRGB_NONLINEAR_KHR {
			found_format = true;
			chosen_format = it;
			break;
		}
	}
	if !found_format
		return false, "No suitable surface format found";
	
	// PRESENT MODES
	available_modes :=  zr.swapchain_details.present_modes;
	chosen_mode : VkPresentModeKHR;
	for available_modes {
		if it == .VK_PRESENT_MODE_MAILBOX_KHR {
			chosen_mode = it;
		}
	}
	if chosen_mode != .VK_PRESENT_MODE_MAILBOX_KHR
		chosen_mode = .VK_PRESENT_MODE_FIFO_KHR;

	// EXTENTS
	capabilities := zr.swapchain_details.capabilities;
	chosen_extent : VkExtent2D;

	if capabilities.currentExtent.width != U32_MAX
		chosen_extent = capabilities.currentExtent;
	else {
		w : u32;
		h : u32;

		SDL_Vulkan_GetDrawableSize :: (window : *SDL_Window, w : *u32, h : *u32) #foreign SDL2;

		SDL_Vulkan_GetDrawableSize(zr.window, *w, *h);
	}
	chosen_extent.width = clamp(chosen_extent.width, capabilities.minImageExtent.width, capabilities.maxImageExtent.width);
	chosen_extent.height = clamp(chosen_extent.height, capabilities.minImageExtent.height, capabilities.maxImageExtent.height);
	print("Swap Extent: %x%\n", chosen_extent.width, chosen_extent.height);

	// IMAGE COUNT
	image_count := capabilities.minImageCount+1;
	if capabilities.maxImageCount != 0 { // if 0 it means no limits
		image_count = clamp(image_count, 0, capabilities.maxImageCount);
	}
	
	create_info : VkSwapchainCreateInfoKHR;
	create_info.sType = .VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
	create_info.surface = zr.surface;
	create_info.minImageCount = image_count;
	create_info.imageFormat = chosen_format.format;
	create_info.imageColorSpace = chosen_format.colorSpace;
	create_info.imageExtent = chosen_extent;
	create_info.imageArrayLayers = 1;
	create_info.imageUsage = .VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;

	queue_indices := zr.queue_indices;
	queue_family_indices := u32.[xx queue_indices.graphics, xx queue_indices.present];
	if queue_indices.graphics != queue_indices.present {
		create_info.imageSharingMode = .VK_SHARING_MODE_CONCURRENT;
		create_info.queueFamilyIndexCount = 2;
		create_info.pQueueFamilyIndices = queue_family_indices.data;
	}
	else {
		create_info.imageSharingMode = .VK_SHARING_MODE_EXCLUSIVE;
		create_info.queueFamilyIndexCount = 0;
		create_info.pQueueFamilyIndices = null;
	}

	create_info.preTransform = zr.swapchain_details.capabilities.currentTransform;
	create_info.compositeAlpha = .VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
	create_info.presentMode = chosen_mode;
	create_info.clipped = VK_TRUE;
	create_info.oldSwapchain = VK_NULL_HANDLE;

	result := vkCreateSwapchainKHR(zr.logical_device, *create_info, null, *zr.swapchain);

	
	if result == .VK_SUCCESS {
		final_image_count : u32;
		vkGetSwapchainImagesKHR(zr.logical_device, zr.swapchain, *final_image_count, null);
		array_resize(*zr.swapchain_images, final_image_count);
		vkGetSwapchainImagesKHR(zr.logical_device, zr.swapchain, *final_image_count, zr.swapchain_images.data);
		zr.swapchain_image_format = chosen_format.format;
		zr.swapchain_extent = chosen_extent;
		return true, "";
	}	
	else return false, sprint("%\n", result);
}

init_imageviews :: (zr: *ZRenderer) -> bool, string {
	swapchain_images := zr.swapchain_images;
	array_resize(*zr.swapchain_imageviews, swapchain_images.count);

	for swapchain_images {
		create_info : VkImageViewCreateInfo;
		create_info.sType = .VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
		create_info.image = it;	
		create_info.viewType = .VK_IMAGE_VIEW_TYPE_2D;
		create_info.format = zr.swapchain_image_format;		

		create_info.components.r = .VK_COMPONENT_SWIZZLE_IDENTITY;
		create_info.components.g = .VK_COMPONENT_SWIZZLE_IDENTITY;
		create_info.components.b = .VK_COMPONENT_SWIZZLE_IDENTITY;
		create_info.components.a = .VK_COMPONENT_SWIZZLE_IDENTITY;

		create_info.subresourceRange.aspectMask = .VK_IMAGE_ASPECT_COLOR_BIT;
		create_info.subresourceRange.baseMipLevel = 0;
		create_info.subresourceRange.levelCount = 1;
		create_info.subresourceRange.baseArrayLayer = 0;
		create_info.subresourceRange.layerCount  = 1;

		result := vkCreateImageView(zr.logical_device, *create_info, null, *zr.swapchain_imageviews[it_index]);
		if result != .VK_SUCCESS {
			return false, sprint("%\n", result);
		}
	}
	return true, "";
}

create_render_pass :: (zr: *ZRenderer) -> bool, string {
	color_attachment_desc : VkAttachmentDescription;
	color_attachment_desc.format = zr.swapchain_image_format;
	color_attachment_desc.samples = .VK_SAMPLE_COUNT_1_BIT;
	color_attachment_desc.loadOp = .VK_ATTACHMENT_LOAD_OP_CLEAR;
	color_attachment_desc.storeOp = .VK_ATTACHMENT_STORE_OP_STORE;
	color_attachment_desc.stencilLoadOp = .VK_ATTACHMENT_LOAD_OP_DONT_CARE;
	color_attachment_desc.stencilStoreOp = .VK_ATTACHMENT_STORE_OP_DONT_CARE;
	color_attachment_desc.initialLayout = .VK_IMAGE_LAYOUT_UNDEFINED;
	color_attachment_desc.finalLayout = .VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;

	color_attachment_ref : VkAttachmentReference;
	color_attachment_ref.attachment = 0;
	color_attachment_ref.layout = .VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

	subpass : VkSubpassDescription;
	subpass.pipelineBindPoint = .VK_PIPELINE_BIND_POINT_GRAPHICS;
	subpass.colorAttachmentCount = 1;
	subpass.pColorAttachments = *color_attachment_ref;

	dependency : VkSubpassDependency;
	dependency.srcSubpass = VK_SUBPASS_EXTERNAL;
	dependency.dstSubpass = 0;
	dependency.srcStageMask = .VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
	dependency.srcAccessMask = 0;
	dependency.dstStageMask = .VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
	dependency.dstAccessMask = .VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;

	render_pass_create_info : VkRenderPassCreateInfo;
	render_pass_create_info.sType = .VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
	render_pass_create_info.attachmentCount = 1;
	render_pass_create_info.pAttachments = *color_attachment_desc;
	render_pass_create_info.subpassCount = 1;
	render_pass_create_info.pSubpasses = *subpass;
	render_pass_create_info.dependencyCount = 1;
	render_pass_create_info.pDependencies = *dependency;

	result := vkCreateRenderPass(zr.logical_device, *render_pass_create_info, null, *zr.render_pass);
	if result != .VK_SUCCESS
		return false, "ERROR: Failed to create Render Pass";

	return true, "";
}

init_graphics_pipeline :: (zr: *ZRenderer) -> bool, string {
	vert_shader_code_string := read_entire_file("src/shaders/shader.vert.spv");
	vert_shader_code := string_to_byte_array(vert_shader_code_string);
	frag_shader_code_string := read_entire_file("src/shaders/shader.frag.spv");
	frag_shader_code := string_to_byte_array(frag_shader_code_string);

	vert_success, vert_error, vert_shader_module := create_shader_module(zr, vert_shader_code);
	frag_success, frag_error, frag_shader_module := create_shader_module(zr, frag_shader_code);
	
	vert_shader_stage_info : VkPipelineShaderStageCreateInfo;
	vert_shader_stage_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
	vert_shader_stage_info.stage = .VK_SHADER_STAGE_VERTEX_BIT;
	vert_shader_stage_info.module = vert_shader_module;
	vert_shader_stage_info.pName = "main";

	frag_shader_stage_info : VkPipelineShaderStageCreateInfo;
	frag_shader_stage_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
	frag_shader_stage_info.stage = .VK_SHADER_STAGE_FRAGMENT_BIT;
	frag_shader_stage_info.module = frag_shader_module;
	frag_shader_stage_info.pName = "main";

	shader_stages : []VkPipelineShaderStageCreateInfo = .[vert_shader_stage_info, frag_shader_stage_info];

	// VERTEX INPUT
	vertex_input_info : VkPipelineVertexInputStateCreateInfo;
	vertex_input_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;
	vertex_input_info.vertexBindingDescriptionCount = 0;
	vertex_input_info.pVertexBindingDescriptions = null;
	vertex_input_info.vertexAttributeDescriptionCount = 0;
	vertex_input_info.pVertexAttributeDescriptions = null;

	// INPUT ASSEMBLY
	input_assembly : VkPipelineInputAssemblyStateCreateInfo;
	input_assembly.sType = .VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
	input_assembly.topology = .VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;
	input_assembly.primitiveRestartEnable = VK_FALSE;
	
	// VIEWPORT
	viewport : VkViewport;
	viewport.x = 0;
	viewport.y = 0;
	viewport.width = xx zr.swapchain_extent.width;
	viewport.height = xx zr.swapchain_extent.height;
	viewport.minDepth = 0;
	viewport.maxDepth = 1;

	// SCISSOR
	scissor : VkRect2D;
	scissor.offset = .{0,0};
	scissor.extent = zr.swapchain_extent;

	dynamic_states : [2]VkDynamicState = .[.VK_DYNAMIC_STATE_VIEWPORT, .VK_DYNAMIC_STATE_SCISSOR];
	
	dyanmic_state_create_info : VkPipelineDynamicStateCreateInfo;
	dyanmic_state_create_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO;
	dyanmic_state_create_info.dynamicStateCount = xx dynamic_states.count;
	dyanmic_state_create_info.pDynamicStates = dynamic_states.data;

	viewport_state_create_info : VkPipelineViewportStateCreateInfo;
	viewport_state_create_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
	viewport_state_create_info.viewportCount = 1;
	viewport_state_create_info.scissorCount = 1;

	rasterizer_create_info : VkPipelineRasterizationStateCreateInfo;
	rasterizer_create_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
	rasterizer_create_info.depthClampEnable = VK_FALSE;
	rasterizer_create_info.rasterizerDiscardEnable = VK_FALSE;
	rasterizer_create_info.polygonMode = .VK_POLYGON_MODE_FILL;
	rasterizer_create_info.lineWidth = 1;
	rasterizer_create_info.cullMode = .VK_CULL_MODE_BACK_BIT;
	rasterizer_create_info.frontFace = .VK_FRONT_FACE_CLOCKWISE;
	rasterizer_create_info.depthBiasEnable = VK_FALSE;
	rasterizer_create_info.depthBiasConstantFactor = 0;
	rasterizer_create_info.depthBiasClamp = 0;
	rasterizer_create_info.depthBiasSlopeFactor  = 0;

	// The rasterizer can alter the depth values by adding a constant value or biasing them based on a fragment's slope. This is sometimes used for shadow mapping, but we won't be using it. Just set depthBiasEnable to VK_FALSE.
	multisampling_create_info : VkPipelineMultisampleStateCreateInfo;
	multisampling_create_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
	multisampling_create_info.sampleShadingEnable = VK_FALSE;
	multisampling_create_info.rasterizationSamples = .VK_SAMPLE_COUNT_1_BIT;
	multisampling_create_info.minSampleShading = 1;
	multisampling_create_info.pSampleMask = null;
	multisampling_create_info.alphaToCoverageEnable = VK_FALSE;
	multisampling_create_info.alphaToOneEnable = VK_FALSE;

	color_blend_attachment : VkPipelineColorBlendAttachmentState;
	color_blend_attachment.colorWriteMask = .VK_COLOR_COMPONENT_R_BIT | .VK_COLOR_COMPONENT_G_BIT | .VK_COLOR_COMPONENT_B_BIT | .VK_COLOR_COMPONENT_A_BIT;
	color_blend_attachment.blendEnable = VK_FALSE;
	color_blend_attachment.srcColorBlendFactor = .VK_BLEND_FACTOR_ONE;
	color_blend_attachment.dstColorBlendFactor = .VK_BLEND_FACTOR_ZERO;
	color_blend_attachment.colorBlendOp = .VK_BLEND_OP_ADD;
	color_blend_attachment.srcAlphaBlendFactor = .VK_BLEND_FACTOR_ONE;
	color_blend_attachment.dstAlphaBlendFactor = .VK_BLEND_FACTOR_ONE;
	color_blend_attachment.alphaBlendOp = .VK_BLEND_OP_ADD;

	color_blending : VkPipelineColorBlendStateCreateInfo ;
	color_blending.sType = .VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
	color_blending.logicOpEnable = VK_FALSE;
	color_blending.logicOp = .VK_LOGIC_OP_COPY; 
	color_blending.attachmentCount = 1;
	color_blending.pAttachments = *color_blend_attachment;
	color_blending.blendConstants[0] = 0; 
	color_blending.blendConstants[1] = 0; 
	color_blending.blendConstants[2] = 0; 
	color_blending.blendConstants[3] = 0; 

	pipeline_layout_info : VkPipelineLayoutCreateInfo;
	pipeline_layout_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
	pipeline_layout_info.setLayoutCount = 0; 
	pipeline_layout_info.pSetLayouts = null; 
	pipeline_layout_info.pushConstantRangeCount = 0; 
	pipeline_layout_info.pPushConstantRanges = null; 

	result := vkCreatePipelineLayout(zr.logical_device, *pipeline_layout_info, null, *zr.pipeline_layout);
	if result != .VK_SUCCESS {
		return false, sprint("%\n", result);
	}

	pipeline_info : VkGraphicsPipelineCreateInfo;
	pipeline_info.sType = .VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
	pipeline_info.stageCount = 2;
	pipeline_info.pStages = shader_stages.data;

	pipeline_info.pVertexInputState = *vertex_input_info;
	pipeline_info.pInputAssemblyState = *input_assembly;
	pipeline_info.pViewportState = *viewport_state_create_info;
	pipeline_info.pRasterizationState = *rasterizer_create_info;
	pipeline_info.pMultisampleState = *multisampling_create_info;
	pipeline_info.pDepthStencilState = null;
	pipeline_info.pColorBlendState = *color_blending;
	pipeline_info.pDynamicState = *dyanmic_state_create_info;
	pipeline_info.layout = zr.pipeline_layout;
	pipeline_info.renderPass = zr.render_pass;
	pipeline_info.subpass = 0;

	pipeline_info.basePipelineHandle = VK_NULL_HANDLE;
	pipeline_info.basePipelineIndex = -1;

	result = vkCreateGraphicsPipelines(zr.logical_device, VK_NULL_HANDLE, 1, *pipeline_info, null, *zr.graphics_pipeline);
	if result != .VK_SUCCESS 
		return false, sprint("%\n", result);

	vkDestroyShaderModule(zr.logical_device, vert_shader_module, null);
    vkDestroyShaderModule(zr.logical_device, frag_shader_module, null);

	return true, "";
}

create_shader_module :: (zr: *ZRenderer, code: [..]u8) -> bool, string, VkShaderModule {
	create_info : VkShaderModuleCreateInfo;
	create_info.sType = .VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
	create_info.codeSize = xx code.count;
	create_info.pCode = xx code.data;

	shader_module : VkShaderModule;
	result := vkCreateShaderModule(zr.logical_device, *create_info, null, *shader_module);
	if result != .VK_SUCCESS 
		return false, sprint("%\n", result), null;
	return true, "", shader_module;
}

create_framebuffers :: (zr: *ZRenderer) -> bool, string {
	array_resize(*zr.swapchain_framebuffers, zr.swapchain_imageviews.count);

	for zr.swapchain_imageviews {
		attachments : [..]VkImageView;
		array_add(*attachments, zr.swapchain_imageviews[it_index]);

		framebuffer_create_info : VkFramebufferCreateInfo;
		framebuffer_create_info.sType = .VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
		framebuffer_create_info.renderPass = zr.render_pass;
		framebuffer_create_info.attachmentCount = 1;
		framebuffer_create_info.pAttachments = attachments.data;
		framebuffer_create_info.width = zr.swapchain_extent.width;
		framebuffer_create_info.height = zr.swapchain_extent.height;
		framebuffer_create_info.layers = 1;

		result := vkCreateFramebuffer(zr.logical_device, *framebuffer_create_info, null, *zr.swapchain_framebuffers[it_index]);
		if result != .VK_SUCCESS
			return false, sprint("%\n", result);
	}

	return true, "";
}

create_command_pool :: (zr: *ZRenderer) -> bool, string {
	queue_family_indices := zr.queue_indices;

	pool_info : VkCommandPoolCreateInfo ;
	pool_info.sType = .VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
	pool_info.flags = .VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
	pool_info.queueFamilyIndex = xx queue_family_indices.graphics;

	result := vkCreateCommandPool(zr.logical_device, *pool_info, null, *zr.command_pool);
	if result != .VK_SUCCESS 
		return false, sprint("%\n", result);

	return true, "";
}

create_command_buffer :: (zr: *ZRenderer) -> bool, string {
	alloc_info : VkCommandBufferAllocateInfo;
	alloc_info.sType = .VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
	alloc_info.commandPool = zr.command_pool;
	alloc_info.level = .VK_COMMAND_BUFFER_LEVEL_PRIMARY;
	alloc_info.commandBufferCount = 1;

	result := vkAllocateCommandBuffers(zr.logical_device, *alloc_info, *zr.command_buffer);
	if result != .VK_SUCCESS 
		return false, sprint("%\n", result);
	return true, "";
}

record_command_buffer :: (zr: *ZRenderer, image_index: u32) -> bool, string {
	begin_info : VkCommandBufferBeginInfo;
	begin_info.sType = .VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
	begin_info.flags = 0;
	begin_info.pInheritanceInfo = null;

	result := vkBeginCommandBuffer(zr.command_buffer, *begin_info);
	if result != .VK_SUCCESS 
		return false, sprint("%\n", result);

	render_pass_info : VkRenderPassBeginInfo;
	render_pass_info.sType = .VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
	render_pass_info.renderPass = zr.render_pass;
	render_pass_info.framebuffer = zr.swapchain_framebuffers[image_index];
	render_pass_info.renderArea.offset = .{0,0};
	render_pass_info.renderArea.extent = zr.swapchain_extent;
	clear_color : VkClearValue = .{.{.[0,0,0,1]}};
	render_pass_info.clearValueCount = 1;
	render_pass_info.pClearValues = *clear_color;

	vkCmdBeginRenderPass(zr.command_buffer, *render_pass_info, .VK_SUBPASS_CONTENTS_INLINE);

	vkCmdBindPipeline(zr.command_buffer, .VK_PIPELINE_BIND_POINT_GRAPHICS, zr.graphics_pipeline);

	viewport : VkViewport;
	viewport.x = 0;
	viewport.y = 0;
	viewport.width = xx zr.swapchain_extent.width;
	viewport.height = xx zr.swapchain_extent.height;
	viewport.minDepth = 0;
	viewport.maxDepth = 1;
	vkCmdSetViewport(zr.command_buffer, 0, 1, *viewport);

	scissor : VkRect2D;
	scissor.offset = .{0,0};
	scissor.extent = zr.swapchain_extent;
	vkCmdSetScissor(zr.command_buffer, 0, 1, *scissor);

	vkCmdDraw(zr.command_buffer, 3, 1, 0, 0);

	vkCmdEndRenderPass(zr.command_buffer);

	result = vkEndCommandBuffer(zr.command_buffer);
	if result != .VK_SUCCESS 
		return false, sprint("%\n", result);
	return true, "";
}

create_sync_objects :: (zr: *ZRenderer) -> bool, string {
	semaphore_create_info : VkSemaphoreCreateInfo;
	semaphore_create_info.sType = .VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;

	result := vkCreateSemaphore(zr.logical_device, *semaphore_create_info, null, *zr.image_available_semaphore);
	if result != .VK_SUCCESS 
		return false, sprint("%\n", result);
	result = vkCreateSemaphore(zr.logical_device, *semaphore_create_info, null, *zr.render_finished_semaphore);
	if result != .VK_SUCCESS 
		return false, sprint("%\n", result);

	fence_create_info : VkFenceCreateInfo;
	fence_create_info.sType = .VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
	fence_create_info.flags = .VK_FENCE_CREATE_SIGNALED_BIT;

	result = vkCreateFence(zr.logical_device, *fence_create_info, null, *zr.in_flight_fence);
	if result != .VK_SUCCESS 
		return false, sprint("%\n", result);

	return true, "";
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
	// Check that the window was successfully created
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
	success, error = init_swapchain(zr);
	if !success return false, error;
	success, error = init_imageviews(zr);
	if !success return false, error;
	success, error = create_render_pass(zr);
	if !success return false, error;
	success, error = init_graphics_pipeline(zr);
	if !success return false, error;
	success, error = create_framebuffers(zr);
	if !success return false, error;
	success, error = create_command_pool(zr);
	if !success return false, error;
	success, error = create_command_buffer(zr);
	if !success return false, error;
	success, error = create_sync_objects(zr);
	if !success return false, error;

	zr.initialized = true;
	return true, "";
}

draw_frame :: (zr: *ZRenderer) {
	vkWaitForFences(zr.logical_device, 1, *zr.in_flight_fence, VK_TRUE, U64_MAX);
	vkResetFences(zr.logical_device, 1, *zr.in_flight_fence);

	image_idx : u32;
	vkAcquireNextImageKHR(zr.logical_device, zr.swapchain, U64_MAX, zr.image_available_semaphore, VK_NULL_HANDLE, *image_idx);
	vkResetCommandBuffer(zr.command_buffer, 0);

	record_command_buffer(zr, image_idx); // This needs to take a command buffer too, what if we have multiple?

	submit_info : VkSubmitInfo;
	submit_info.sType = .VK_STRUCTURE_TYPE_SUBMIT_INFO;

	wait_semaphores : [..]VkSemaphore;
	array_add(*wait_semaphores, zr.image_available_semaphore);
	wait_stages : [..]VkPipelineStageFlags;
	array_add(*wait_stages, .VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT);
	submit_info.waitSemaphoreCount = 1;
	submit_info.pWaitSemaphores = wait_semaphores.data;
	submit_info.pWaitDstStageMask = wait_stages.data;

	submit_info.commandBufferCount = 1;
	submit_info.pCommandBuffers = *zr.command_buffer;

	signal_semaphores : [..]VkSemaphore;
	array_add(*signal_semaphores, zr.render_finished_semaphore);
	submit_info.signalSemaphoreCount = 1;
	submit_info.pSignalSemaphores = signal_semaphores.data;

	result := vkQueueSubmit(zr.graphics_queue, 1, *submit_info, zr.in_flight_fence);
	if result != .VK_SUCCESS {
		print("%\n", result);
		return;
	}
		
	present_info : VkPresentInfoKHR;
	present_info.sType = .VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
	present_info.waitSemaphoreCount = 1;
	present_info.pWaitSemaphores = signal_semaphores.data;

	swap_chains : [..]VkSwapchainKHR;
	array_add(*swap_chains, zr.swapchain);
	present_info.swapchainCount = 1;
	present_info.pSwapchains = swap_chains.data;
	present_info.pImageIndices = *image_idx;
	present_info.pResults = null;

	vkQueuePresentKHR(zr.present_queue, *present_info);

	SDL_GL_SwapWindow(zr.window); 
}

deinit_zrenderer :: (zr: *ZRenderer) {
	if zr.initialized {
		vkDestroySemaphore(zr.logical_device, zr.image_available_semaphore, null);
		vkDestroySemaphore(zr.logical_device, zr.render_finished_semaphore, null);
		vkDestroyFence(zr.logical_device, zr.in_flight_fence, null);

		vkDestroyCommandPool(zr.logical_device, zr.command_pool, null);

		for zr.swapchain_framebuffers {
			vkDestroyFramebuffer(zr.logical_device, it, null);
		}
		for zr.swapchain_imageviews {
			vkDestroyImageView(zr.logical_device, it, null);
		}
		
		vkDestroyPipeline(zr.logical_device, zr.graphics_pipeline, null);
		vkDestroyPipelineLayout(zr.logical_device, zr.pipeline_layout, null);
		vkDestroyRenderPass(zr.logical_device, zr.render_pass, null);
		vkDestroySwapchainKHR(zr.logical_device, zr.swapchain, null);
		vkDestroySurfaceKHR(zr.instance, zr.surface, null);
		vkDestroyDevice(zr.logical_device, null);
		vkDestroyInstance(zr.instance, null);
		
		SDL_DestroyWindow(zr.window);
	}
	SDL_Quit();
}