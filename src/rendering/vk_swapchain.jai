
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


init_swapchain :: (zr: *ZRenderer) -> bool, string {
	
	// FORMAT
	available_formats := zr.swapchain_details.formats;
	chosen_format : VkSurfaceFormatKHR;
	found_format : bool;
	// TODO: HDR
	for available_formats {
		if it.format == .VK_FORMAT_B8G8R8A8_SRGB && it.colorSpace == .VK_COLOR_SPACE_SRGB_NONLINEAR_KHR {
			found_format = true;
			chosen_format = it;
			break;
		}
	}
	if !found_format {
		return false, "No suitable surface format found";
	}
		
	
	// PRESENT MODES
	available_modes :=  zr.swapchain_details.present_modes;
	chosen_mode : VkPresentModeKHR;
	for available_modes {
		if it == .VK_PRESENT_MODE_MAILBOX_KHR {
			chosen_mode = it;
			break;
		}
	}
	if chosen_mode != .VK_PRESENT_MODE_MAILBOX_KHR {
		chosen_mode = .VK_PRESENT_MODE_IMMEDIATE_KHR;
	}
		

	// EXTENTS
	capabilities := zr.swapchain_details.capabilities;
	chosen_extent : VkExtent2D;

	if capabilities.currentExtent.width != U32_MAX {
		chosen_extent = capabilities.currentExtent;
	}
	else {
		w : u32;
		h : u32;

		SDL_Vulkan_GetDrawableSize(zr.window, *w, *h);
		chosen_extent.width = w;
		chosen_extent.height = h;
	}

	chosen_extent.width = clamp(chosen_extent.width, capabilities.minImageExtent.width, capabilities.maxImageExtent.width);
	chosen_extent.height = clamp(chosen_extent.height, capabilities.minImageExtent.height, capabilities.maxImageExtent.height);
	zr.resolution = chosen_extent;
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

	result := vkCreateSwapchainKHR(zr.device, *create_info, null, *zr.swapchain);
	if result != .VK_SUCCESS 
		return false, sprint("%\n", result);

	final_image_count : u32;
	vkGetSwapchainImagesKHR(zr.device, zr.swapchain, *final_image_count, null);
	array_resize(*zr.swapchain_images, final_image_count);
	vkGetSwapchainImagesKHR(zr.device, zr.swapchain, *final_image_count, zr.swapchain_images.data);
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

		result := vkCreateImageView(zr.device, *create_info, null, *zr.swapchain_imageviews[it_index]);
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
	result = vmaCreateImage(VMA_ALLOCATOR, *rimg_create_info, *rimg_alloc_info, *zr.draw_image.image, *zr.draw_image.allocation, null);
	if result != .VK_SUCCESS {
		return false, sprint("%\n", result);
	}


	zr.draw_extent.width = draw_image_extent.width;
	zr.draw_extent.height = draw_image_extent.height;

	// Build imageview for the draw image to use for rendering 
	rview_info : VkImageViewCreateInfo = vkinit_imageview_create_info(zr.draw_image.image_format, zr.draw_image.image, .VK_IMAGE_ASPECT_COLOR_BIT);

	result = vkCreateImageView(zr.device, *rview_info, null, *zr.draw_image.image_view);
	if result != .VK_SUCCESS {
		return false, sprint("%\n", result);
	}

	if(ENABLE_VALIDATION_LAYERS) {
		set_vk_object_name(zr.device, .IMAGE, cast(u64)zr.draw_image.image, "Draw Image");
		set_vk_object_name(zr.device, .IMAGE_VIEW, cast(u64)zr.draw_image.image_view, "Draw Image View");
	}

	queue_deletion(*GLOBAL_DELETION_QUEUE, zr.device, zr.draw_image.image_view);
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, zr.draw_image.image, zr.draw_image.allocation);

	// DEPTH IMAGE
	zr.depth_image.image_format = .VK_FORMAT_D32_SFLOAT;
	zr.depth_image.image_extent = draw_image_extent;
	depth_image_usages : VkImageUsageFlags;
	depth_image_usages |= .VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT;

	depth_image_info : VkImageCreateInfo = vkinit_image_create_info(zr.depth_image.image_format, depth_image_usages, draw_image_extent);
	vmaCreateImage(VMA_ALLOCATOR, *depth_image_info, *rimg_alloc_info, *zr.depth_image.image, *zr.depth_image.allocation, null);

	depth_view_info : VkImageViewCreateInfo  = vkinit_imageview_create_info(zr.depth_image.image_format, zr.depth_image.image, .VK_IMAGE_ASPECT_DEPTH_BIT);

	result = vkCreateImageView(zr.device, *depth_view_info, null, *zr.depth_image.image_view);
	if result != .VK_SUCCESS {
		return false, sprint("%\n", result);
	}

	if(ENABLE_VALIDATION_LAYERS) {
		set_vk_object_name(zr.device, .IMAGE, cast(u64)zr.depth_image.image, "Depth Image");
		set_vk_object_name(zr.device, .IMAGE_VIEW, cast(u64)zr.depth_image.image_view, "Depth Image View");
	}

	queue_deletion(*GLOBAL_DELETION_QUEUE, zr.device, zr.depth_image.image_view);
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, zr.depth_image.image, zr.depth_image.allocation);

	return true, "";
}

resize_swapchain :: (zr: *ZRenderer) {
	vkDeviceWaitIdle(zr.device);

	destroy_swapchain(zr);

	w : u32;
	h : u32;
	SDL_Vulkan_GetDrawableSize(zr.window, *w, *h);
	zr.window_extents.width = cast,no_check(u32) w;
	zr.window_extents.height = cast,no_check(u32) h;
	

	print("W: % H: %\n", w,h);
	query_swapchain_support(zr);
	init_swapchain(zr);
	zr.resize_requested = false;
}

destroy_swapchain :: (zr: *ZRenderer) {
	vkDestroySwapchainKHR(zr.device, zr.swapchain, null);

	// destroy swapchain resources
	for <zr.swapchain_imageviews {
		vkDestroyImageView(zr.device, it, null);
	}
}
