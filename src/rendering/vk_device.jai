#import "Basic";
#import "Math";
#import "SDL";
#import "Vulkan"(USE_VULKAN_1_1 = true)(MEMORY_ALLOCATOR_DEBUG = false, USE_LOCAL_VULKAN_DYNAMIC_LIB = false);

Required_Extensions :: (*u8).[
    "VK_EXT_debug_utils",
];

Required_Device_Extensions :: (*u8).[
    VK_KHR_SWAPCHAIN_EXTENSION_NAME,
	VK_EXT_DESCRIPTOR_BUFFER_EXTENSION_NAME,
];

Desired_Validation_Layers :: (*u8).[
    "VK_LAYER_KHRONOS_validation",
];


ENABLE_VALIDATION_LAYERS :: true;
vkSetDebugUtilsObjectNameEXT : PFN_vkSetDebugUtilsObjectNameEXT;


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
	if ENABLE_VALIDATION_LAYERS {
		array_add(*required_extensions, VK_EXT_DEBUG_UTILS_EXTENSION_NAME);
	}

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

	// Load the debug utils function pointer
    if ENABLE_VALIDATION_LAYERS {
        vkSetDebugUtilsObjectNameEXT = cast(PFN_vkSetDebugUtilsObjectNameEXT) 
        vkGetInstanceProcAddr(zr.instance, "vkSetDebugUtilsObjectNameEXT");
        
        if !vkSetDebugUtilsObjectNameEXT {
            print("Warning: Failed to load vkSetDebugUtilsObjectNameEXT\n");
        }
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

	descriptor_buffer_features : VkPhysicalDeviceDescriptorBufferFeaturesEXT;
	descriptor_buffer_features.sType = .VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DESCRIPTOR_BUFFER_FEATURES_EXT;
	descriptor_buffer_features.descriptorBuffer = VK_TRUE;

	device_featuresVK13 : VkPhysicalDeviceVulkan13Features;
	device_featuresVK13.pNext = *descriptor_buffer_features;
	device_featuresVK13.synchronization2 = VK_TRUE;
	device_featuresVK13.dynamicRendering = VK_TRUE;

	device_featuresVK12 : VkPhysicalDeviceVulkan12Features;
	device_featuresVK12.pNext = *device_featuresVK13;
	device_featuresVK12.bufferDeviceAddress = VK_TRUE;
	device_featuresVK12.runtimeDescriptorArray = VK_TRUE;

	device_featuresVK11 : VkPhysicalDeviceVulkan11Features;
	device_featuresVK11.pNext = *device_featuresVK12;

	device_featuresVk : VkPhysicalDeviceFeatures2;
	device_featuresVk.features.shaderInt64 = VK_TRUE;
	device_featuresVk.pNext = *device_featuresVK11;

	device_create_info : VkDeviceCreateInfo;
    device_create_info.sType = .VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
    device_create_info.pNext = *device_featuresVk;  
    device_create_info.queueCreateInfoCount = xx queue_create_infos.count;
    device_create_info.pQueueCreateInfos = queue_create_infos.data;
    device_create_info.pEnabledFeatures = null;  
    device_create_info.enabledExtensionCount = xx Required_Device_Extensions.count;
    device_create_info.ppEnabledExtensionNames = Required_Device_Extensions.data;

	if ENABLE_VALIDATION_LAYERS {
		device_create_info.enabledLayerCount = Desired_Validation_Layers.count;
		device_create_info.ppEnabledLayerNames = Desired_Validation_Layers.data;
	} else device_create_info.enabledLayerCount = 0;

	result := vkCreateDevice(zr.physical_device, *device_create_info, null, *zr.device);
	
	vkGetDescriptorEXT = cast(PFN_vkGetDescriptorEXT) vkGetDeviceProcAddr(zr.device, "vkGetDescriptorEXT");
    if !vkGetDescriptorEXT {
        panic("ERROR: Failed to load vkGetDescriptorEXT");
    }

	vkGetDeviceQueue(zr.device, cast,no_check(u32)zr.queue_indices.graphics, 0, *zr.graphics_queue);
	if zr.queue_indices.present != zr.queue_indices.graphics {
    	vkGetDeviceQueue(zr.device, cast,no_check(u32)zr.queue_indices.present, 0, *zr.present_queue);
	} else {
		zr.present_queue = zr.graphics_queue; 
	}
	if result == .VK_SUCCESS {return true, "";}
	else return false, sprint("%\n", result);
}

create_vma_allocator :: (physical_device: VkPhysicalDevice, logical_device: VkDevice, instance: VkInstance) -> bool, string {
	allocator_create_info : VmaAllocatorCreateInfo;
	allocator_create_info.physicalDevice = physical_device;
	allocator_create_info.device = logical_device;
	allocator_create_info.instance = instance;
	allocator_create_info.flags = .VMA_ALLOCATOR_CREATE_BUFFER_DEVICE_ADDRESS_BIT;
	allocator_create_info.vulkanApiVersion = VK_API_VERSION_1_3;
	vmaCreateAllocator(*allocator_create_info, *VMA_ALLOCATOR);

	return true, "";
}