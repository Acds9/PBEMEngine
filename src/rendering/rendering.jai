#import "Basic";
#import "Math";
#import "SDL";
#import "Vulkan"(USE_VULKAN_1_1 = true)(MEMORY_ALLOCATOR_DEBUG = false, USE_LOCAL_VULKAN_DYNAMIC_LIB = false);
ImGui :: #import "ImGui";

Required_Extensions :: (*u8).[
    "VK_EXT_debug_utils",
];

Required_Device_Extensions :: (*u8).[
	VK_KHR_SWAPCHAIN_EXTENSION_NAME,
];

Desired_Validation_Layers :: (*u8).[
    "VK_LAYER_KHRONOS_validation",
];

SDL_Vulkan_GetInstanceExtensions :: (window : *SDL_Window, num_extensions : *u32, extensions : **u8) -> SDL_bool #foreign SDL2;
SDL_Vulkan_CreateSurface :: (window : *SDL_Window, instance : VkInstance, surface : *VkSurfaceKHR) -> SDL_bool #foreign SDL2;
SDL_Vulkan_GetDrawableSize :: (window : *SDL_Window, w : *u32, h : *u32) #foreign SDL2;

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
	array_reset(*image_views);
	array_reset(*images);
	array_reset(*desc_layouts);
	array_reset(*pipeline_layouts);
	array_reset(*pipelines);
	array_reset(*command_pools);
	array_reset(*fences);
}

Frame_Data :: struct {
	command_pool 			: VkCommandPool;
	command_buffer			: VkCommandBuffer;

	image_available_semaphore 	: VkSemaphore;
	render_finished_semaphore 	: VkSemaphore;
	in_flight_fence				: VkFence;

	deletion_queue				: Deletion_Queue;
}

Allocated_Image :: struct {
	image			: VkImage;
	image_view		: VkImageView;
	allocation		: VmaAllocation;
	image_extent	: VkExtent3D;
	image_format	: VkFormat;
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
}
/*
immediate_submit :: (function: (command_buffer: VkCommandBuffer, ctx: *void) -> void, context: *void) {
	
}*/

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
        print("MESSAGE (VK): %\n", msg);
    }

    return VK_FALSE;
}

create_surface :: (zr: *ZRenderer) -> bool, string {
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
		queue_create_info : VkDeviceQueueCreateInfo = vkinit_device_queue_create_info(xx it, *queue_priority);
		array_add(*queue_create_infos, queue_create_info);
	}
	device_features : VkPhysicalDeviceFeatures;

	device_featueresVK13 : VkPhysicalDeviceVulkan13Features;
	device_featueresVK13.synchronization2 = VK_TRUE;

	device_featueresVK12 : VkPhysicalDeviceVulkan12Features;
	device_featueresVK12.pNext = *device_featueresVK13;

	device_featueresVK11 : VkPhysicalDeviceVulkan11Features;
	device_featueresVK11.pNext = *device_featueresVK12;

	device_create_info : VkDeviceCreateInfo = vkinit_device_create_info(*device_featueresVK11, queue_create_infos, *device_features, Required_Device_Extensions);

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

		SDL_Vulkan_GetDrawableSize(zr.window, *w, *h);
		chosen_extent.width = w;
		chosen_extent.height = h;
	}

	chosen_extent.width = clamp(chosen_extent.width, capabilities.minImageExtent.width, capabilities.maxImageExtent.width);
	chosen_extent.height = clamp(chosen_extent.height, capabilities.minImageExtent.height, capabilities.maxImageExtent.height);
	print("Swap Extent: %x%\n", chosen_extent.width, chosen_extent.height);

	// IMAGE COUNT
	image_count := capabilities.minImageCount+1;
	if capabilities.maxImageCount != 0 { // if 0 it means no limits
		image_count = clamp(image_count, 0, capabilities.maxImageCount);
	}
	
	create_info : VkSwapchainCreateInfoKHR = vkinit_swapchain_create_info(
		zr.surface, 
		image_count, 
		chosen_format, 
		chosen_extent,
		zr.swapchain_details.capabilities.currentTransform,
		.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
		chosen_mode,
		VK_TRUE,
		VK_NULL_HANDLE,
		image_usage = .VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | .VK_IMAGE_USAGE_TRANSFER_DST_BIT
	);

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

	result := vkCreateSwapchainKHR(zr.logical_device, *create_info, null, *zr.swapchain);

	
	if result != .VK_SUCCESS 
		return false, sprint("%\n", result);

	final_image_count : u32;
	vkGetSwapchainImagesKHR(zr.logical_device, zr.swapchain, *final_image_count, null);
	array_resize(*zr.swapchain_images, final_image_count);
	vkGetSwapchainImagesKHR(zr.logical_device, zr.swapchain, *final_image_count, zr.swapchain_images.data);
	zr.swapchain_image_format = chosen_format.format;
	zr.swapchain_extent = chosen_extent;

	// IMAGE VIEWS
	swapchain_images := zr.swapchain_images;
	array_resize(*zr.swapchain_imageviews, swapchain_images.count);

	components : VkComponentMapping = .{
		.VK_COMPONENT_SWIZZLE_IDENTITY,
		.VK_COMPONENT_SWIZZLE_IDENTITY,
		.VK_COMPONENT_SWIZZLE_IDENTITY,
		.VK_COMPONENT_SWIZZLE_IDENTITY};
	subresource_range : VkImageSubresourceRange = vkinit_subresource_range(.VK_IMAGE_ASPECT_COLOR_BIT);
	
	for swapchain_images {
		create_info : VkImageViewCreateInfo = vkinit_imageview_create_info(it, .VK_IMAGE_VIEW_TYPE_2D, zr.swapchain_image_format, components, subresource_range);

		result := vkCreateImageView(zr.logical_device, *create_info, null, *zr.swapchain_imageviews[it_index]);
		if result != .VK_SUCCESS {
			return false, sprint("%\n", result);
		}
	}


	// Match window
	draw_image_extent : VkExtent3D;
	draw_image_extent.width = chosen_extent.width;
	draw_image_extent.height = chosen_extent.height;
	draw_image_extent.depth = 1;

	// 32bit float
	zr.draw_image.image_format = .VK_FORMAT_R16G16B16A16_SFLOAT;
	zr.draw_image.image_extent = draw_image_extent;

	draw_image_usage_flags : VkImageUsageFlags;
	draw_image_usage_flags |= .VK_IMAGE_USAGE_TRANSFER_SRC_BIT;
	draw_image_usage_flags |= .VK_IMAGE_USAGE_TRANSFER_DST_BIT;
	draw_image_usage_flags |= .VK_IMAGE_USAGE_STORAGE_BIT;
	draw_image_usage_flags |= .VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;

	rimg_create_info : VkImageCreateInfo = vkinit_image_create_info(zr.draw_image.image_format, draw_image_usage_flags, draw_image_extent);

	// alloc from GPU local memory
	rimg_alloc_info : VmaAllocationCreateInfo;
	rimg_alloc_info.usage = .VMA_MEMORY_USAGE_GPU_ONLY;
	rimg_alloc_info.requiredFlags = .VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT;

	// Allocate and create
	result = vmaCreateImage(zr.allocator, *rimg_create_info, *rimg_alloc_info, *zr.draw_image.image, *zr.draw_image.allocation, null);
	if result != .VK_SUCCESS {
		return false, sprint("%\n", result);
	}

	zr.draw_extent.width = draw_image_extent.width;
	zr.draw_extent.height = draw_image_extent.height;

	// Build imageview for the draw image to use for rendering 
	rview_info : VkImageViewCreateInfo = vkinit_imageview_create_info(zr.draw_image.image_format, zr.draw_image.image, .VK_IMAGE_ASPECT_COLOR_BIT);

	result = vkCreateImageView(zr.logical_device, *rview_info, null, *zr.draw_image.image_view);
	if result != .VK_SUCCESS {
		return false, sprint("%\n", result);
	}

	array_add(*zr.deletion_queue.image_views, .{zr.logical_device, zr.draw_image.image_view});
	array_add(*zr.deletion_queue.images, .{zr.allocator, zr.draw_image.image, zr.draw_image.allocation});

	return true, "";
}

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

init_pipelines :: (zr: *ZRenderer) -> bool, string {
	init_background_pipelines(zr);
	return true, "";
}

init_background_pipelines :: (zr: *ZRenderer) -> bool, string {
	compute_layout : VkPipelineLayoutCreateInfo;
	compute_layout.sType = .VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
	compute_layout.pSetLayouts = *zr.draw_image_desc_layout;
	compute_layout.setLayoutCount = 1;

	result := vkCreatePipelineLayout(zr.logical_device, *compute_layout, null, *zr.gradient_pipeline_layout);
	if result != .VK_SUCCESS {
		return false, sprint("%\n", result); 
	}
	
	compute_draw_shader : VkShaderModule;
	success				: bool;
	success, compute_draw_shader = create_shader_module(zr, "src/shaders/gradient.comp.spv");
	if !success {
		return false, "Failed to create compute shader, check SPIR-V file.";
	}
	stage_info : VkPipelineShaderStageCreateInfo;
	stage_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
	stage_info.stage = .VK_SHADER_STAGE_COMPUTE_BIT;
	stage_info.module = compute_draw_shader;
	stage_info.pName = "main";

	compute_pipeline_create_info : VkComputePipelineCreateInfo;
	compute_pipeline_create_info.sType = .VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO;
	compute_pipeline_create_info.layout = zr.gradient_pipeline_layout;
	compute_pipeline_create_info.stage = stage_info;

	result = vkCreateComputePipelines(zr.logical_device, null, 1, *compute_pipeline_create_info, null, *zr.gradient_pipeline);
	if result != .VK_SUCCESS {
		return false, sprint("%\n", result); 
	}

	// Shader module has been used and can be deleted already
	vkDestroyShaderModule(zr.logical_device, compute_draw_shader, null);
	// Rest has to go at deinit
	array_add(*zr.deletion_queue.pipelines, .{zr.logical_device, zr.gradient_pipeline});
	array_add(*zr.deletion_queue.pipeline_layouts, .{zr.logical_device, zr.gradient_pipeline_layout});

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

record_command_buffer :: (zr: *ZRenderer, command_buffer: VkCommandBuffer, image_index: u32) -> bool, string {
    begin_info := vkinit_command_buffer_begin_info();
    
    result := vkBeginCommandBuffer(command_buffer, *begin_info);
    if result != .VK_SUCCESS 
        return false, sprint("%\n", result);
    
    // Transition main draw image into general layout so we can write to it
    vkutil_transition_image(command_buffer, zr.draw_image.image, .VK_IMAGE_LAYOUT_UNDEFINED, .VK_IMAGE_LAYOUT_GENERAL);

	// Bind the gradient drawing compute pipeline
	vkCmdBindPipeline(command_buffer, .VK_PIPELINE_BIND_POINT_COMPUTE, zr.gradient_pipeline);

	// bind the descriptor set containing the draw image for the compute pipeline
	vkCmdBindDescriptorSets(command_buffer, .VK_PIPELINE_BIND_POINT_COMPUTE, zr.gradient_pipeline_layout, 0, 1, *zr.draw_image_descs, 0, null);

	// execute the compute pipeline dispatch. We are using 16x16 workgroup size so we need to divide by it
	vkCmdDispatch(command_buffer, cast,no_check(u32) ceil(zr.draw_extent.width / 16.0), cast,no_check(u32) ceil(zr.draw_extent.height / 16.0), 1);
    
    // Transition the draw image and the swapchain image into their correct transfer layouts
    vkutil_transition_image(command_buffer, zr.draw_image.image, .VK_IMAGE_LAYOUT_GENERAL, .VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL);
    vkutil_transition_image(command_buffer, zr.swapchain_images[image_index], .VK_IMAGE_LAYOUT_UNDEFINED, .VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL);

    // Execute a copy from the draw image into the swapchain
    vkutil_blit_copy_image_image(command_buffer, zr.draw_image.image, zr.swapchain_images[image_index], zr.draw_extent, zr.swapchain_extent);

    // set swapchain image layout to Present so we can show it on the screen
    vkutil_transition_image(command_buffer, zr.swapchain_images[image_index], .VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, .VK_IMAGE_LAYOUT_PRESENT_SRC_KHR);

    result = vkEndCommandBuffer(command_buffer);
    if result != .VK_SUCCESS 
        return false, sprint("%\n", result);
    return true, "";
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

create_vma_allocator :: (zr: *ZRenderer) -> bool, string {
	allocator_create_info : VmaAllocatorCreateInfo;
	allocator_create_info.physicalDevice = zr.physical_device;
	allocator_create_info.device = zr.logical_device;
	allocator_create_info.instance = zr.instance;
	allocator_create_info.flags = .VMA_ALLOCATOR_CREATE_BUFFER_DEVICE_ADDRESS_BIT;
	allocator_create_info.vulkanApiVersion = VK_API_VERSION_1_3;
	vmaCreateAllocator(*allocator_create_info, *zr.allocator);

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

immediate_submit :: (zr: *ZRenderer, function: (cmd: VkCommandBuffer) -> ()) {
	vkResetFences(zr.logical_device, 1, *zr.immediate_fence);
	vkResetCommandBuffer(zr.immediate_command_buffer, 0);

	cmd := zr.immediate_command_buffer;

	cmd_begin_info : VkCommandBufferBeginInfo = vkinit_command_buffer_begin_info(.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT);
	vkBeginCommandBuffer(cmd, *cmd_begin_info);

	function(cmd);

	vkEndCommandBuffer(cmd);

	cmd_info : VkCommandBufferSubmitInfo = vkinit_command_buffer_submit_info(cmd);
	submit_info : VkSubmitInfo2 = vk_init_submit_info2(*cmd_info, null, null);

	vkQueueSubmit2(zr.graphics_queue, 1, *submit_info, zr.immediate_fence);

	vkWaitForFences(zr.logical_device, 1, *zr.immediate_fence, 1, 1000000000);
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


	record_command_buffer(zr, frame_data.command_buffer, image_idx); 

	submit_info : VkSubmitInfo2;
	submit_info.sType = .VK_STRUCTURE_TYPE_SUBMIT_INFO_2;

	// Make a function?
	wait_semaphore_info : VkSemaphoreSubmitInfo = vkinit_semaphore_submit_info(
		frame_data.image_available_semaphore,
		VK_PIPELINE_STAGE_2_COMPUTE_SHADER_BIT
    );
	// 
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

deinit_swapchain :: (zr: *ZRenderer) {
	for zr.swapchain_framebuffers {
		vkDestroyFramebuffer(zr.logical_device, it, null);
	}
	for zr.swapchain_imageviews {
		vkDestroyImageView(zr.logical_device, it, null);
	}
	vkDestroySwapchainKHR(zr.logical_device, zr.swapchain, null);
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

