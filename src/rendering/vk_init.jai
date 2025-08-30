
vkinit_device_queue_create_info :: (queue_family_index: u32, queue_priority: *float, queue_count: u32 = 1) -> VkDeviceQueueCreateInfo {
	create_info : VkDeviceQueueCreateInfo;
	create_info.sType = .VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
	create_info.queueFamilyIndex = queue_family_index;
	create_info.queueCount = queue_count;
	create_info.pQueuePriorities = queue_priority;
	return create_info;
}

vkinit_device_create_info :: (next: *void, queue_create_infos: []VkDeviceQueueCreateInfo, enabled_features: *VkPhysicalDeviceFeatures, device_extensions: []*u8) -> VkDeviceCreateInfo{
	create_info : VkDeviceCreateInfo;
	create_info.sType = .VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
	create_info.pNext = next;
	create_info.queueCreateInfoCount = xx queue_create_infos.count;
	create_info.pQueueCreateInfos = queue_create_infos.data;
	create_info.pEnabledFeatures = enabled_features;
	create_info.enabledExtensionCount = xx device_extensions.count;
	create_info.ppEnabledExtensionNames = device_extensions.data;
	return create_info;
}

// NB: Queue family setup is left to the caller
vkinit_swapchain_create_info :: (surface: VkSurfaceKHR, min_image_count: u32, format: VkSurfaceFormatKHR, extent: VkExtent2D, 
                                 pre_transform: VkSurfaceTransformFlagBitsKHR, composite_alpha: VkCompositeAlphaFlagBitsKHR,
                                 present_mode: VkPresentModeKHR, clipped: VkBool32, old_swapchain: VkSwapchainKHR,
                                 image_array_layers: u32 = 1, image_usage: VkImageUsageFlags = .VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT) -> VkSwapchainCreateInfoKHR {
    create_info : VkSwapchainCreateInfoKHR;
    create_info.sType = .VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
    create_info.surface = surface;
    create_info.minImageCount = min_image_count;
    create_info.imageFormat = format.format;
    create_info.imageColorSpace = format.colorSpace;
    create_info.imageExtent = extent;
    create_info.imageArrayLayers = image_array_layers;
    create_info.imageUsage = image_usage;
    create_info.preTransform = pre_transform;
    create_info.compositeAlpha = composite_alpha;
    create_info.presentMode = present_mode;
    create_info.clipped = clipped;
    create_info.oldSwapchain = old_swapchain;
    create_info.imageSharingMode = .VK_SHARING_MODE_EXCLUSIVE;
    create_info.queueFamilyIndexCount = 0;
    create_info.pQueueFamilyIndices = null;
    
    return create_info;
}

vkinit_subresource_range :: (aspect_mask: VkImageAspectFlags, base_mip_level: u32 = 0, level_count: u32 = 1, base_array_layer : u32 = 0, layer_count : u32 = 1) -> VkImageSubresourceRange {
	subresource : VkImageSubresourceRange;	
	subresource.aspectMask = .VK_IMAGE_ASPECT_COLOR_BIT;
	subresource.baseMipLevel = 0;
	subresource.levelCount = 1;
	subresource.baseArrayLayer = 0;
	subresource.layerCount  = 1;
	return subresource;
}

vkinit_imageview_create_info :: (image: VkImage, view_type: VkImageViewType, format: VkFormat, components: VkComponentMapping, subresource_range: VkImageSubresourceRange) -> VkImageViewCreateInfo {
	create_info : VkImageViewCreateInfo;
	create_info.sType = .VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
	create_info.image = image;	
	create_info.viewType = view_type;
	create_info.format = format;		
	create_info.components = components;
	create_info.subresourceRange = subresource_range;
	return create_info;
}

vkinit_attachment_description :: (format: VkFormat, samples: VkSampleCountFlagBits, 
                                  load_op: VkAttachmentLoadOp, store_op: VkAttachmentStoreOp,
                                  stencil_load_op: VkAttachmentLoadOp, stencil_store_op: VkAttachmentStoreOp,
                                  initial_layout: VkImageLayout, final_layout: VkImageLayout,
                                  flags: VkAttachmentDescriptionFlags = 0) -> VkAttachmentDescription {
    desc: VkAttachmentDescription;
    desc.flags = flags;
    desc.format = format;
    desc.samples = samples;
    desc.loadOp = load_op;
    desc.storeOp = store_op;
    desc.stencilLoadOp = stencil_load_op;
    desc.stencilStoreOp = stencil_store_op;
    desc.initialLayout = initial_layout;
    desc.finalLayout = final_layout;
    return desc;
}

vkinit_attachment_reference :: (attachment: u32, layout: VkImageLayout) -> VkAttachmentReference {
    ref: VkAttachmentReference;
    ref.attachment = attachment;
    ref.layout = layout;
    return ref;
}

vkinit_subpass_description :: (pipeline_bind_point: VkPipelineBindPoint,
                               color_attachment_count: u32 = 0, color_attachments: *VkAttachmentReference = null,
                               input_attachment_count: u32 = 0, input_attachments: *VkAttachmentReference = null,
                               resolve_attachments: *VkAttachmentReference = null,
                               depth_stencil_attachment: *VkAttachmentReference = null,
                               preserve_attachment_count: u32 = 0, preserve_attachments: *u32 = null,
                               flags: VkSubpassDescriptionFlags = 0) -> VkSubpassDescription {
    subpass: VkSubpassDescription;
    subpass.flags = flags;
    subpass.pipelineBindPoint = pipeline_bind_point;
    subpass.inputAttachmentCount = input_attachment_count;
    subpass.pInputAttachments = input_attachments;
    subpass.colorAttachmentCount = color_attachment_count;
    subpass.pColorAttachments = color_attachments;
    subpass.pResolveAttachments = resolve_attachments;
    subpass.pDepthStencilAttachment = depth_stencil_attachment;
    subpass.preserveAttachmentCount = preserve_attachment_count;
    subpass.pPreserveAttachments = preserve_attachments;
    return subpass;
}

vkinit_subpass_dependency :: (src_subpass: u32, dst_subpass: u32,
                              src_stage_mask: VkPipelineStageFlags, dst_stage_mask: VkPipelineStageFlags,
                              src_access_mask: VkAccessFlags, dst_access_mask: VkAccessFlags,
                              dependency_flags: VkDependencyFlags = 0) -> VkSubpassDependency {
    dependency: VkSubpassDependency;
    dependency.srcSubpass = src_subpass;
    dependency.dstSubpass = dst_subpass;
    dependency.srcStageMask = src_stage_mask;
    dependency.dstStageMask = dst_stage_mask;
    dependency.srcAccessMask = src_access_mask;
    dependency.dstAccessMask = dst_access_mask;
    dependency.dependencyFlags = dependency_flags;
    return dependency;
}

vkinit_render_pass_create_info :: (attachment_count: u32, attachments: *VkAttachmentDescription,
                                   subpass_count: u32, subpasses: *VkSubpassDescription,
                                   dependency_count: u32 = 0, dependencies: *VkSubpassDependency = null,
                                   flags: VkRenderPassCreateFlags = 0) -> VkRenderPassCreateInfo {
    create_info: VkRenderPassCreateInfo;
    create_info.sType = .VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
    create_info.pNext = null;
    create_info.flags = flags;
    create_info.attachmentCount = attachment_count;
    create_info.pAttachments = attachments;
    create_info.subpassCount = subpass_count;
    create_info.pSubpasses = subpasses;
    create_info.dependencyCount = dependency_count;
    create_info.pDependencies = dependencies;
    return create_info;
}

vkinit_pipeline_shader_stage_create_info :: (stage: VkShaderStageFlagBits, module: VkShaderModule, 
                                             entry_name: *u8, specialization_info: *VkSpecializationInfo = null,
                                             flags: VkPipelineShaderStageCreateFlags = 0) -> VkPipelineShaderStageCreateInfo {
    create_info: VkPipelineShaderStageCreateInfo;
    create_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    create_info.pNext = null;
    create_info.flags = flags;
    create_info.stage = stage;
    create_info.module = module;
    create_info.pName = entry_name;
    create_info.pSpecializationInfo = specialization_info;
    return create_info;
}

vkinit_pipeline_vertex_input_state_create_info :: (vertex_binding_description_count: u32 = 0, 
                                                   vertex_binding_descriptions: *VkVertexInputBindingDescription = null,
                                                   vertex_attribute_description_count: u32 = 0,
                                                   vertex_attribute_descriptions: *VkVertexInputAttributeDescription = null,
                                                   flags: VkPipelineVertexInputStateCreateFlags = 0) -> VkPipelineVertexInputStateCreateInfo {
    create_info: VkPipelineVertexInputStateCreateInfo;
    create_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;
    create_info.pNext = null;
    create_info.flags = flags;
    create_info.vertexBindingDescriptionCount = vertex_binding_description_count;
    create_info.pVertexBindingDescriptions = vertex_binding_descriptions;
    create_info.vertexAttributeDescriptionCount = vertex_attribute_description_count;
    create_info.pVertexAttributeDescriptions = vertex_attribute_descriptions;
    return create_info;
}

vkinit_pipeline_input_assembly_state_create_info :: (topology: VkPrimitiveTopology, 
                                                     primitive_restart_enable: VkBool32,
                                                     flags: VkPipelineInputAssemblyStateCreateFlags = 0) -> VkPipelineInputAssemblyStateCreateInfo {
    create_info: VkPipelineInputAssemblyStateCreateInfo;
    create_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
    create_info.pNext = null;
    create_info.flags = flags;
    create_info.topology = topology;
    create_info.primitiveRestartEnable = primitive_restart_enable;
    return create_info;
}

vkinit_pipeline_viewport_state_create_info :: (viewport_count: u32, viewports: *VkViewport = null,
                                               scissor_count: u32, scissors: *VkRect2D = null,
                                               flags: VkPipelineViewportStateCreateFlags = 0) -> VkPipelineViewportStateCreateInfo {
    create_info: VkPipelineViewportStateCreateInfo;
    create_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
    create_info.pNext = null;
    create_info.flags = flags;
    create_info.viewportCount = viewport_count;
    create_info.pViewports = viewports;
    create_info.scissorCount = scissor_count;
    create_info.pScissors = scissors;
    return create_info;
}

vkinit_pipeline_rasterization_state_create_info :: (polygon_mode: VkPolygonMode, cull_mode: VkCullModeFlags, 
                                                    front_face: VkFrontFace, line_width: float32,
                                                    depth_clamp_enable: VkBool32 = VK_FALSE,
                                                    rasterizer_discard_enable: VkBool32 = VK_FALSE,
                                                    depth_bias_enable: VkBool32 = VK_FALSE,
                                                    depth_bias_constant_factor: float32 = 0,
                                                    depth_bias_clamp: float32 = 0,
                                                    depth_bias_slope_factor: float32 = 0,
                                                    flags: VkPipelineRasterizationStateCreateFlags = 0) -> VkPipelineRasterizationStateCreateInfo {
    create_info: VkPipelineRasterizationStateCreateInfo;
    create_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
    create_info.pNext = null;
    create_info.flags = flags;
    create_info.depthClampEnable = depth_clamp_enable;
    create_info.rasterizerDiscardEnable = rasterizer_discard_enable;
    create_info.polygonMode = polygon_mode;
    create_info.cullMode = cull_mode;
    create_info.frontFace = front_face;
    create_info.depthBiasEnable = depth_bias_enable;
    create_info.depthBiasConstantFactor = depth_bias_constant_factor;
    create_info.depthBiasClamp = depth_bias_clamp;
    create_info.depthBiasSlopeFactor = depth_bias_slope_factor;
    create_info.lineWidth = line_width;
    return create_info;
}

vkinit_pipeline_multisample_state_create_info :: (rasterization_samples: VkSampleCountFlagBits,
                                                  sample_shading_enable: VkBool32 = VK_FALSE,
                                                  min_sample_shading: float32 = 1.0,
                                                  sample_mask: *VkSampleMask = null,
                                                  alpha_to_coverage_enable: VkBool32 = VK_FALSE,
                                                  alpha_to_one_enable: VkBool32 = VK_FALSE,
                                                  flags: VkPipelineMultisampleStateCreateFlags = 0) -> VkPipelineMultisampleStateCreateInfo {
    create_info: VkPipelineMultisampleStateCreateInfo;
    create_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
    create_info.pNext = null;
    create_info.flags = flags;
    create_info.rasterizationSamples = rasterization_samples;
    create_info.sampleShadingEnable = sample_shading_enable;
    create_info.minSampleShading = min_sample_shading;
    create_info.pSampleMask = sample_mask;
    create_info.alphaToCoverageEnable = alpha_to_coverage_enable;
    create_info.alphaToOneEnable = alpha_to_one_enable;
    return create_info;
}

vkinit_pipeline_color_blend_attachment_state :: (color_write_mask: VkColorComponentFlags,
                                                 blend_enable: VkBool32 = VK_FALSE,
                                                 src_color_blend_factor: VkBlendFactor = .VK_BLEND_FACTOR_ONE,
                                                 dst_color_blend_factor: VkBlendFactor = .VK_BLEND_FACTOR_ZERO,
                                                 color_blend_op: VkBlendOp = .VK_BLEND_OP_ADD,
                                                 src_alpha_blend_factor: VkBlendFactor = .VK_BLEND_FACTOR_ONE,
                                                 dst_alpha_blend_factor: VkBlendFactor = .VK_BLEND_FACTOR_ZERO,
                                                 alpha_blend_op: VkBlendOp = .VK_BLEND_OP_ADD) -> VkPipelineColorBlendAttachmentState {
    state: VkPipelineColorBlendAttachmentState;
    state.blendEnable = blend_enable;
    state.srcColorBlendFactor = src_color_blend_factor;
    state.dstColorBlendFactor = dst_color_blend_factor;
    state.colorBlendOp = color_blend_op;
    state.srcAlphaBlendFactor = src_alpha_blend_factor;
    state.dstAlphaBlendFactor = dst_alpha_blend_factor;
    state.alphaBlendOp = alpha_blend_op;
    state.colorWriteMask = color_write_mask;
    return state;
}

vkinit_pipeline_color_blend_state_create_info :: (attachment_count: u32, attachments: *VkPipelineColorBlendAttachmentState,
                                                  logic_op_enable: VkBool32 = VK_FALSE,
                                                  logic_op: VkLogicOp = .VK_LOGIC_OP_COPY,
                                                  blend_constant_r: float32 = 0, blend_constant_g: float32 = 0,
                                                  blend_constant_b: float32 = 0, blend_constant_a: float32 = 0,
                                                  flags: VkPipelineColorBlendStateCreateFlags = 0) -> VkPipelineColorBlendStateCreateInfo {
    create_info: VkPipelineColorBlendStateCreateInfo;
    create_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
    create_info.pNext = null;
    create_info.flags = flags;
    create_info.logicOpEnable = logic_op_enable;
    create_info.logicOp = logic_op;
    create_info.attachmentCount = attachment_count;
    create_info.pAttachments = attachments;
    create_info.blendConstants[0] = blend_constant_r;
    create_info.blendConstants[1] = blend_constant_g;
    create_info.blendConstants[2] = blend_constant_b;
    create_info.blendConstants[3] = blend_constant_a;
    return create_info;
}

vkinit_pipeline_dynamic_state_create_info :: (dynamic_state_count: u32, dynamic_states: *VkDynamicState,
                                              flags: VkPipelineDynamicStateCreateFlags = 0) -> VkPipelineDynamicStateCreateInfo {
    create_info: VkPipelineDynamicStateCreateInfo;
    create_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO;
    create_info.pNext = null;
    create_info.flags = flags;
    create_info.dynamicStateCount = dynamic_state_count;
    create_info.pDynamicStates = dynamic_states;
    return create_info;
}

vkinit_pipeline_layout_create_info :: (set_layout_count: u32 = 0, set_layouts: *VkDescriptorSetLayout = null,
                                       push_constant_range_count: u32 = 0, push_constant_ranges: *VkPushConstantRange = null,
                                       flags: VkPipelineLayoutCreateFlags = 0) -> VkPipelineLayoutCreateInfo {
    create_info: VkPipelineLayoutCreateInfo;
    create_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
    create_info.pNext = null;
    create_info.flags = flags;
    create_info.setLayoutCount = set_layout_count;
    create_info.pSetLayouts = set_layouts;
    create_info.pushConstantRangeCount = push_constant_range_count;
    create_info.pPushConstantRanges = push_constant_ranges;
    return create_info;
}

vkinit_graphics_pipeline_create_info :: (stage_count: u32, stages: *VkPipelineShaderStageCreateInfo,
                                         vertex_input_state: *VkPipelineVertexInputStateCreateInfo,
                                         input_assembly_state: *VkPipelineInputAssemblyStateCreateInfo,
                                         viewport_state: *VkPipelineViewportStateCreateInfo,
                                         rasterization_state: *VkPipelineRasterizationStateCreateInfo,
                                         multisample_state: *VkPipelineMultisampleStateCreateInfo,
                                         color_blend_state: *VkPipelineColorBlendStateCreateInfo,
                                         layout: VkPipelineLayout,
                                         render_pass: VkRenderPass,
                                         subpass: u32,
                                         depth_stencil_state: *VkPipelineDepthStencilStateCreateInfo = null,
                                         dynamic_state: *VkPipelineDynamicStateCreateInfo = null,
                                         tessellation_state: *VkPipelineTessellationStateCreateInfo = null,
                                         base_pipeline_handle: VkPipeline = VK_NULL_HANDLE,
                                         base_pipeline_index: s32 = -1,
                                         flags: VkPipelineCreateFlags = 0) -> VkGraphicsPipelineCreateInfo {
    create_info: VkGraphicsPipelineCreateInfo;
    create_info.sType = .VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
    create_info.pNext = null;
    create_info.flags = flags;
    create_info.stageCount = stage_count;
    create_info.pStages = stages;
    create_info.pVertexInputState = vertex_input_state;
    create_info.pInputAssemblyState = input_assembly_state;
    create_info.pTessellationState = tessellation_state;
    create_info.pViewportState = viewport_state;
    create_info.pRasterizationState = rasterization_state;
    create_info.pMultisampleState = multisample_state;
    create_info.pDepthStencilState = depth_stencil_state;
    create_info.pColorBlendState = color_blend_state;
    create_info.pDynamicState = dynamic_state;
    create_info.layout = layout;
    create_info.renderPass = render_pass;
    create_info.subpass = subpass;
    create_info.basePipelineHandle = base_pipeline_handle;
    create_info.basePipelineIndex = base_pipeline_index;
    return create_info;
}

vkinit_framebuffer_create_info :: (render_pass: VkRenderPass, attachment_count: u32, attachments: *VkImageView,
                                   width: u32, height: u32, layers: u32 = 1,
                                   flags: VkFramebufferCreateFlags = 0) -> VkFramebufferCreateInfo {
    create_info: VkFramebufferCreateInfo;
    create_info.sType = .VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
    create_info.pNext = null;
    create_info.flags = flags;
    create_info.renderPass = render_pass;
    create_info.attachmentCount = attachment_count;
    create_info.pAttachments = attachments;
    create_info.width = width;
    create_info.height = height;
    create_info.layers = layers;
    return create_info;
}

vkinit_command_buffer_begin_info :: (flags: VkCommandBufferUsageFlags = 0,
                                     inheritance_info: *VkCommandBufferInheritanceInfo = null) -> VkCommandBufferBeginInfo {
    begin_info: VkCommandBufferBeginInfo;
    begin_info.sType = .VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
    begin_info.pNext = null;
    begin_info.flags = flags;
    begin_info.pInheritanceInfo = inheritance_info;
    return begin_info;
}

vkinit_render_pass_begin_info :: (render_pass: VkRenderPass, framebuffer: VkFramebuffer,
                                  render_area: VkRect2D, clear_value_count: u32 = 0,
                                  clear_values: *VkClearValue = null) -> VkRenderPassBeginInfo {
    begin_info: VkRenderPassBeginInfo;
    begin_info.sType = .VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
    begin_info.pNext = null;
    begin_info.renderPass = render_pass;
    begin_info.framebuffer = framebuffer;
    begin_info.renderArea = render_area;
    begin_info.clearValueCount = clear_value_count;
    begin_info.pClearValues = clear_values;
    return begin_info;
}

vkinit_viewport :: (x: float32, y: float32, width: float32, height: float32,
                   min_depth: float32 = 0.0, max_depth: float32 = 1.0) -> VkViewport {
    viewport: VkViewport;
    viewport.x = x;
    viewport.y = y;
    viewport.width = width;
    viewport.height = height;
    viewport.minDepth = min_depth;
    viewport.maxDepth = max_depth;
    return viewport;
}

vkinit_semaphore_submit_info :: (semaphore: VkSemaphore, stage_mask: VkPipelineStageFlags2,
                                 value: u64 = 1, device_index: u32 = 0) -> VkSemaphoreSubmitInfo {
    submit_info: VkSemaphoreSubmitInfo;
    submit_info.sType = .VK_STRUCTURE_TYPE_SEMAPHORE_SUBMIT_INFO;
    submit_info.pNext = null;
    submit_info.semaphore = semaphore;
    submit_info.value = value;
    submit_info.stageMask = stage_mask;
    submit_info.deviceIndex = device_index;
    return submit_info;
}

vkinit_image_create_info :: (format: VkFormat, usage_flags: VkImageUsageFlags, extent: VkExtent3D, 
								image_type: VkImageType = .VK_IMAGE_TYPE_2D, mip_levels: u32 = 1, array_layers: u32 = 1, samples: 
								VkSampleCountFlagBits = .VK_SAMPLE_COUNT_1_BIT, tiling : VkImageTiling = .VK_IMAGE_TILING_OPTIMAL, next: *void = null) -> VkImageCreateInfo {
	image_create_info : VkImageCreateInfo;

	image_create_info.sType = .VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
    image_create_info.pNext = next;

    image_create_info.imageType = image_type;

    image_create_info.format = format;
    image_create_info.extent = extent;

    image_create_info.mipLevels = mip_levels;
    image_create_info.arrayLayers = array_layers;

    image_create_info.samples = samples;

    image_create_info.tiling = tiling;
    image_create_info.usage = usage_flags;

	return image_create_info;
}

vkinit_imageview_create_info :: (format : VkFormat, image : VkImage, aspectFlags : VkImageAspectFlags, 
									image_type: VkImageViewType = .VK_IMAGE_VIEW_TYPE_2D, base_mip_level : u32 = 0, level_count : u32 = 1,
									base_array_layer : u32 = 0, layer_count : u32 = 1, next : *void = null) -> VkImageViewCreateInfo
{
    create_info : VkImageViewCreateInfo;
    create_info.sType = .VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
    create_info.pNext = next;

    create_info.viewType = image_type;
    create_info.image = image;
    create_info.format = format;
    create_info.subresourceRange.baseMipLevel = base_mip_level;
    create_info.subresourceRange.levelCount = level_count;
    create_info.subresourceRange.baseArrayLayer = base_array_layer;
    create_info.subresourceRange.layerCount = layer_count;
    create_info.subresourceRange.aspectMask = aspectFlags;

    return create_info;
}

// TODO: rename this file to vkutils

vkutil_blit_copy_image_image :: (command_buffer : VkCommandBuffer, src: VkImage , dst: VkImage, src_size: VkExtent2D, dst_size: VkExtent2D) {
	blit_region : VkImageBlit2;
	blit_region.sType = .VK_STRUCTURE_TYPE_IMAGE_BLIT_2;

	blit_region.srcOffsets[1].x = cast,no_check(s32)src_size.width;
	blit_region.srcOffsets[1].y = cast,no_check(s32)src_size.height;
	blit_region.srcOffsets[1].z = 1;

	blit_region.dstOffsets[1].x = cast,no_check(s32)dst_size.width;
	blit_region.dstOffsets[1].y = cast,no_check(s32)dst_size.height;
	blit_region.dstOffsets[1].z = 1;

	blit_region.srcSubresource.aspectMask = .VK_IMAGE_ASPECT_COLOR_BIT;
	blit_region.srcSubresource.baseArrayLayer = 0;
	blit_region.srcSubresource.layerCount = 1;
	blit_region.srcSubresource.mipLevel = 0;

	blit_region.dstSubresource.aspectMask = .VK_IMAGE_ASPECT_COLOR_BIT;
	blit_region.dstSubresource.baseArrayLayer = 0;
	blit_region.dstSubresource.layerCount = 1;
	blit_region.dstSubresource.mipLevel = 0;

	blit_info : VkBlitImageInfo2;
	blit_info.sType = .VK_STRUCTURE_TYPE_BLIT_IMAGE_INFO_2;

	blit_info.dstImage = dst;
	blit_info.dstImageLayout = .VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
	blit_info.srcImage = src;
	blit_info.srcImageLayout = .VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
	blit_info.filter = .VK_FILTER_LINEAR;
	blit_info.regionCount = 1;
	blit_info.pRegions = *blit_region;

	vkCmdBlitImage2(command_buffer, *blit_info);
}

vkutil_transition_image :: (command_buffer: VkCommandBuffer, image: VkImage, current_layout: VkImageLayout, new_layout: VkImageLayout)
{
    image_barrier : VkImageMemoryBarrier2;
	image_barrier.sType = .VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER_2;

    image_barrier.srcStageMask = VK_PIPELINE_STAGE_2_ALL_COMMANDS_BIT;
    image_barrier.srcAccessMask = VK_ACCESS_2_MEMORY_WRITE_BIT;
    image_barrier.dstStageMask = VK_PIPELINE_STAGE_2_ALL_COMMANDS_BIT;
    image_barrier.dstAccessMask = VK_ACCESS_2_MEMORY_WRITE_BIT | VK_ACCESS_2_MEMORY_READ_BIT;

    image_barrier.oldLayout = current_layout;
    image_barrier.newLayout = new_layout;

    aspect_mask : VkImageAspectFlags = ifx new_layout == .VK_IMAGE_LAYOUT_DEPTH_ATTACHMENT_OPTIMAL then .VK_IMAGE_ASPECT_DEPTH_BIT else .VK_IMAGE_ASPECT_COLOR_BIT;
    image_barrier.subresourceRange = vkinit_subresource_range(aspect_mask, 0, VK_REMAINING_MIP_LEVELS, 0, VK_REMAINING_ARRAY_LAYERS);
    image_barrier.image = image;

    dep_info : VkDependencyInfo;
    dep_info.sType = .VK_STRUCTURE_TYPE_DEPENDENCY_INFO;

    dep_info.imageMemoryBarrierCount = 1;
    dep_info.pImageMemoryBarriers = *image_barrier;

    vkCmdPipelineBarrier2(command_buffer, *dep_info);
}