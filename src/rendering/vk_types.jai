Color :: struct  {
	r, g, b, a : u8;
}

COLOR_BLACK		:: Color.{0, 0, 0, 255};
COLOR_GREY 		:: Color.{127,127,127,255};
COLOR_WHITE 	:: Color.{255, 255, 255, 255};
COLOR_MAGENTA 	:: Color.{255, 0, 255, 255};

color_to_vec4 :: (c: *Color) -> Vector4 {
	return .{
			cast,no_check(float)c.r, 
			cast,no_check(float)c.g, 
			cast,no_check(float)c.b, 
			cast,no_check(float)c.a};
}

Color_HDR :: struct {
	r, g, b, a : float32;

	to_r10g10b10a2 :: (using self: *Color_HDR) -> u32 {
		r1 := cast,no_check(u32)(clamp(r, 0, 1) * 1023.0);
		g1 := cast,no_check(u32)(clamp(g, 0, 1) * 1023.0);
		b1 := cast,no_check(u32)(clamp(b, 0, 1) * 1023.0);
		a1 := cast,no_check(u32)(clamp(a, 0, 1) * 3.0);
		return r1 | (g1 << 10) | (b1 << 20) | (a1 << 30);
	}
}

Swapchain_Support_Details :: struct {
    capabilities    : VkSurfaceCapabilitiesKHR;
    formats        : [..]VkSurfaceFormatKHR;
    present_modes  : [..]VkPresentModeKHR;
}

Allocated_Image :: struct {
    image          : VkImage;
    image_view     : VkImageView;
    allocation     : VmaAllocation;
    image_extent   : VkExtent3D;
    image_format   : VkFormat;
}

Queue_Family_Indices :: struct {
    graphics : s32 = -1;
    present  : s32 = -1;
    compute  : s32 = -1;
    transfer : s32 = -1;

    is_complete :: (using self: Queue_Family_Indices) -> bool {
        return graphics > -1 && present > -1;
    }
}

Pipeline_Builder :: struct {
	shader_stages 			: [..]VkPipelineShaderStageCreateInfo;

	input_assembly			: VkPipelineInputAssemblyStateCreateInfo;
    rasterizer				: VkPipelineRasterizationStateCreateInfo;
    color_blend_attachment 	: VkPipelineColorBlendAttachmentState;
    multisampling			: VkPipelineMultisampleStateCreateInfo;
    pipeline_layout			: VkPipelineLayout;
    depth_stencil			: VkPipelineDepthStencilStateCreateInfo;
    render_info				: VkPipelineRenderingCreateInfo;
    color_attachment_format	: VkFormat;

	// DEBUG
	vk_debug_name			: string;

	reset :: (self: *Pipeline_Builder) {
		using self;
		
		input_assembly 			= .{sType = .VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO};
		rasterizer				= .{sType = .VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO};
		color_blend_attachment 	= .{};
		multisampling			= .{sType = .VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO};
		pipeline_layout			= null;
		depth_stencil			= .{sType = .VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO};
		render_info				= .{sType = .VK_STRUCTURE_TYPE_PIPELINE_RENDERING_CREATE_INFO};
		array_reset(*shader_stages);
	}

	build :: (self: *Pipeline_Builder, zr: *ZRenderer) -> VkPipeline {
		using self;
		viewport_state : VkPipelineViewportStateCreateInfo;
		viewport_state.sType = .VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;

		viewport_state.viewportCount = 1;
		viewport_state.scissorCount = 1;

		color_blending : VkPipelineColorBlendStateCreateInfo;
		color_blending.sType = .VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;

		color_blending.logicOpEnable = VK_FALSE;
		color_blending.logicOp = .VK_LOGIC_OP_COPY;
		color_blending.attachmentCount = 1;
		color_blending.pAttachments = *color_blend_attachment;

		vertex_input_info : VkPipelineVertexInputStateCreateInfo;
		vertex_input_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;
		// Build the actual pipeline
		
		pipeline_info : VkGraphicsPipelineCreateInfo;
		pipeline_info.sType = .VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
		// Connect the renderInfo
		pipeline_info.pNext = *render_info;
	
		pipeline_info.stageCount = cast,no_check(u32)shader_stages.count;
		pipeline_info.pStages = shader_stages.data;
		pipeline_info.pVertexInputState = *vertex_input_info;
		pipeline_info.pInputAssemblyState = *input_assembly;
		pipeline_info.pViewportState = *viewport_state;
		pipeline_info.pRasterizationState = *rasterizer;
		pipeline_info.pMultisampleState = *multisampling;
		pipeline_info.pColorBlendState = *color_blending;
		pipeline_info.pDepthStencilState = *depth_stencil;
		pipeline_info.layout = pipeline_layout;

		state : []VkDynamicState = .[.VK_DYNAMIC_STATE_VIEWPORT, .VK_DYNAMIC_STATE_SCISSOR];

		dynamic_info : VkPipelineDynamicStateCreateInfo;
		dynamic_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO;
		dynamic_info.pDynamicStates = *state[0];
		dynamic_info.dynamicStateCount = 2;

		pipeline_info.pDynamicState = *dynamic_info;

		new_pipeline : VkPipeline;
		if(vkCreateGraphicsPipelines(zr.device, VK_NULL_HANDLE, 1, *pipeline_info, null, *new_pipeline) != .VK_SUCCESS) {
			panic("ERROR: Pipeline creation failed");
			return null;
		} else {
			if(ENABLE_VALIDATION_LAYERS) {
				if(vk_debug_name == "") {
					panic("ERROR: vk_debug_name not set for pipeline in debug\n");
					return null;
				}
				set_vk_object_name(zr.device, .PIPELINE, cast(u64)new_pipeline, vk_debug_name);
			}
			queue_deletion(*GLOBAL_DELETION_QUEUE, zr.device, new_pipeline);
			return new_pipeline;
		}
	}

	set_shaders :: (self: *Pipeline_Builder, vertex_shader: VkShaderModule, fragment_shader: VkShaderModule) {
		using self;

		array_reset(*shader_stages);

		array_add(*shader_stages, vkinit_pipeline_shader_stage_create_info(.VK_SHADER_STAGE_VERTEX_BIT, vertex_shader, "main"));
		array_add(*shader_stages, vkinit_pipeline_shader_stage_create_info(.VK_SHADER_STAGE_FRAGMENT_BIT, fragment_shader, "main"));
	}

	set_input_topology :: (self: *Pipeline_Builder, topology: VkPrimitiveTopology) {
		using self;

		input_assembly.topology = topology;
		input_assembly.primitiveRestartEnable = VK_FALSE;
	}

	set_polygon_mode :: (self: *Pipeline_Builder, mode: VkPolygonMode ) {
		using self;

		rasterizer.polygonMode = mode;
		rasterizer.lineWidth = 1;
	}

	set_cull_mode :: (self: *Pipeline_Builder, mode: VkCullModeFlags, front_face: VkFrontFace) {
		using self;

		rasterizer.cullMode = mode;
		rasterizer.frontFace = front_face;
	}

	set_multisampling_none :: (self: *Pipeline_Builder) { // Expand later
		using self;

		multisampling.sampleShadingEnable = VK_FALSE;
		// Multisampling defaulted to no multisampling (1 sample per pixel)
		multisampling.rasterizationSamples = .VK_SAMPLE_COUNT_1_BIT;
		multisampling.minSampleShading = 1;
		multisampling.pSampleMask = null;
		// No alpha to coverage either
		multisampling.alphaToCoverageEnable = VK_FALSE;
		multisampling.alphaToOneEnable = VK_FALSE;
	}

	enable_blending_additive :: (using self: *Pipeline_Builder) {
		color_blend_attachment.colorWriteMask = .VK_COLOR_COMPONENT_R_BIT | .VK_COLOR_COMPONENT_G_BIT | .VK_COLOR_COMPONENT_B_BIT | .VK_COLOR_COMPONENT_A_BIT;
		color_blend_attachment.blendEnable = VK_TRUE;
		color_blend_attachment.srcColorBlendFactor = .VK_BLEND_FACTOR_SRC_ALPHA;
		color_blend_attachment.dstColorBlendFactor = .VK_BLEND_FACTOR_ONE;
		color_blend_attachment.colorBlendOp = .VK_BLEND_OP_ADD;
		color_blend_attachment.srcAlphaBlendFactor = .VK_BLEND_FACTOR_ONE;
		color_blend_attachment.dstAlphaBlendFactor = .VK_BLEND_FACTOR_ZERO;
		color_blend_attachment.alphaBlendOp = .VK_BLEND_OP_ADD;
	}

	enable_blending_alphablend :: (using self: *Pipeline_Builder) {
		color_blend_attachment.colorWriteMask = .VK_COLOR_COMPONENT_R_BIT | .VK_COLOR_COMPONENT_G_BIT | .VK_COLOR_COMPONENT_B_BIT | .VK_COLOR_COMPONENT_A_BIT;
		color_blend_attachment.blendEnable = VK_TRUE;
		color_blend_attachment.srcColorBlendFactor = .VK_BLEND_FACTOR_SRC_ALPHA;
		color_blend_attachment.dstColorBlendFactor = .VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA;
		color_blend_attachment.colorBlendOp = .VK_BLEND_OP_ADD;
		color_blend_attachment.srcAlphaBlendFactor = .VK_BLEND_FACTOR_ONE;
		color_blend_attachment.dstAlphaBlendFactor = .VK_BLEND_FACTOR_ZERO;
		color_blend_attachment.alphaBlendOp = .VK_BLEND_OP_ADD;
	}

	disable_blending :: (self: *Pipeline_Builder) {
		using self;

		color_blend_attachment.colorWriteMask = .VK_COLOR_COMPONENT_R_BIT | .VK_COLOR_COMPONENT_G_BIT | .VK_COLOR_COMPONENT_B_BIT | .VK_COLOR_COMPONENT_A_BIT;
		color_blend_attachment.blendEnable = VK_FALSE;
	}

	set_color_attachment_format :: (self: *Pipeline_Builder, format: VkFormat) {
		using self;

		color_attachment_format = format;
		render_info.colorAttachmentCount = 1;
		render_info.pColorAttachmentFormats = *color_attachment_format;
	}

	enable_depthtest :: (self: *Pipeline_Builder, depth_write_enable: bool, op: VkCompareOp) {
		using self;
		depth_stencil.depthTestEnable = VK_TRUE;
		depth_stencil.depthWriteEnable = xx depth_write_enable;
		depth_stencil.depthCompareOp = op;
		depth_stencil.depthBoundsTestEnable = VK_FALSE;
		depth_stencil.stencilTestEnable = VK_FALSE;
		depth_stencil.front = .{};
		depth_stencil.back = .{};
		depth_stencil.minDepthBounds = 0;
		depth_stencil.maxDepthBounds = 1;
	}

	set_depth_format :: (self: *Pipeline_Builder, format: VkFormat) {
		using self;

		render_info.depthAttachmentFormat  = format;
	}

	disable_depthtest :: (self: *Pipeline_Builder) {
		using self;

		depth_stencil.depthTestEnable = VK_FALSE;
		depth_stencil.depthWriteEnable = VK_FALSE;
		depth_stencil.depthCompareOp = .VK_COMPARE_OP_NEVER;
		depth_stencil.depthBoundsTestEnable = VK_FALSE;
		depth_stencil.stencilTestEnable = VK_FALSE;
		depth_stencil.front = .{};
		depth_stencil.back = .{};
		depth_stencil.minDepthBounds = 0;
		depth_stencil.maxDepthBounds = 1;
	}

	set_vk_object_name :: (self: *Pipeline_Builder, name: string) {
		using self;
		vk_debug_name = name;
	}
}

Vertex :: struct {
	position	: Vector3;
	uv_x		: float;
	normal		: Vector3;
	uv_y		: float;
	color		: Vector4;
}

GPU_Mesh_Buffers :: struct {
	index_buffer			: Allocated_Buffer;
	vertex_buffer			: Allocated_Buffer;
	vertex_buffer_address 	: VkDeviceAddress;
}

GPU_Draw_Push_Constants :: struct {
	transform_address	: VkDeviceAddress;
	vertex_buffer		: VkDeviceAddress;
	material_address	: VkDeviceAddress;
	camera_data_address : VkDeviceAddress;
	image_index			: u32;      
    sampler_index		: u32;    
}

Render_Transform :: struct {
	local_transform	: Matrix4;
	parent_address	: VkDeviceAddress;
}


Mesh_Instance :: struct {
	mesh_asset			: *Mesh_Asset; 
	transform_address	: VkDeviceAddress;
	generation			: u8;

	get_render_transform :: (using self: *Mesh_Instance) -> *Render_Transform {
		return cast,no_check(*Render_Transform)transform_address;
	}
}

calculate_transform_depth :: (transform: *Render_Transform) -> u8 {
	depth : u8 = 0;
	current_transform := transform;
	while current_transform.parent_address != 0 {
		depth += 1;
		current_transform = cast,no_check(*Render_Transform) current_transform.parent_address;
	}
	return depth;
}

calculate_world_transform :: (base_transform: *Render_Transform) -> Matrix4 {
	current_transform := base_transform;
	world_transform := current_transform.local_transform;
	while current_transform.parent_address != 0 {
		current_transform = cast,no_check(*Render_Transform) current_transform.parent_address;
		world_transform = current_transform.local_transform * world_transform;
	}
	return world_transform;
}