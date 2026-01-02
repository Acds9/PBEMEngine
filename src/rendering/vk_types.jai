Swapchain_Support_Details :: struct {
    capabilities    : VkSurfaceCapabilitiesKHR;
    formats        : [..]VkSurfaceFormatKHR;
    present_modes  : [..]VkPresentModeKHR;
}

Allocated_Image :: struct {
    image          	: VkImage;
    image_view     	: VkImageView;
    allocation     	: VmaAllocation;
    image_extent   	: VkExtent3D;
    image_format   	: VkFormat;
	image_name		: string;
	image_index		: u32;
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
	dynamic_states			: [..]VkDynamicState;
	
	spec_data: [..]u8;
	spec_entries: [..]VkSpecializationMapEntry;
	spec_info: VkSpecializationInfo;

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
		
		array_reset(*spec_data);
		array_reset(*spec_entries);
		spec_info = .{};

		array_reset(*dynamic_states);
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
		pipeline_info.flags = .VK_PIPELINE_CREATE_DESCRIPTOR_BUFFER_BIT_EXT;
		pipeline_info.pStages = shader_stages.data;
		pipeline_info.pVertexInputState = *vertex_input_info;
		pipeline_info.pInputAssemblyState = *input_assembly;
		pipeline_info.pViewportState = *viewport_state;
		pipeline_info.pRasterizationState = *rasterizer;
		pipeline_info.pMultisampleState = *multisampling;
		pipeline_info.pColorBlendState = *color_blending;
		pipeline_info.pDepthStencilState = *depth_stencil;
		pipeline_info.layout = pipeline_layout;

		array_add(*dynamic_states, .VK_DYNAMIC_STATE_VIEWPORT);
		array_add(*dynamic_states, .VK_DYNAMIC_STATE_SCISSOR);

		dynamic_info : VkPipelineDynamicStateCreateInfo;
		dynamic_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO;
		dynamic_info.pDynamicStates = dynamic_states.data;
		dynamic_info.dynamicStateCount = xx dynamic_states.count;

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

	set_line_width :: (self: *Pipeline_Builder, width: float) {
		using self;

		rasterizer.lineWidth = width;
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

	add_dynamic_state :: (using self: *Pipeline_Builder, state: VkDynamicState) {
		array_add(*dynamic_states, state);
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

	add_specialization_constant :: (self: *Pipeline_Builder, stage: VkShaderStageFlagBits, constant_id: u32, value: $T) {
		using self;
    
		entry: VkSpecializationMapEntry = .{
			constantID = constant_id,
			offset = cast(u32)spec_data.count,
			size = size_of(T)
		};
		array_add(*spec_entries, entry);
    
		// Append value bytes
		value_bytes := cast(*u8)*value;
		for 0..size_of(T)-1 {
			array_add(*spec_data, value_bytes[it]);
		}
    
		// Update specinfo
		spec_info.mapEntryCount = cast(u32)spec_entries.count;
		spec_info.pMapEntries = spec_entries.data;
		spec_info.dataSize = cast(u64)spec_data.count;
		spec_info.pData = spec_data.data;
    
		// Update the shader stage
		for *shader_stages {
			if it.stage == stage {
				it.pSpecializationInfo = *spec_info;
				break;
			}
		}
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

Draw_Push_Constants :: struct {
	render_globals					: VkDeviceAddress;
	bda_draws						: VkDeviceAddress;
	bda_flattened_transforms		: VkDeviceAddress;
	bda_vertices					: VkDeviceAddress;
	bda_camera						: VkDeviceAddress;
	bda_materials					: VkDeviceAddress;
	bda_cluster_index				: VkDeviceAddress;
	bda_point_lights				: VkDeviceAddress;
	point_lights_count				: u32;

	#if true { // DEBUG_BUILD not being recognized?
		light_cluster_mode	: u32; // None, depth slice, flat rainbow, depth rainbow, heatmap 

	}
}

Debug_Point_Push_Constants :: struct {
	render_globals		: VkDeviceAddress;
	bda_vertex			: VkDeviceAddress;
	bda_camera			: VkDeviceAddress;
}

Debug_Mesh_Push_Constants :: struct {
	render_globals		: VkDeviceAddress;
	bda_draw			: VkDeviceAddress;
	bda_vertex			: VkDeviceAddress;
	bda_transform		: VkDeviceAddress;
	bda_materials		: VkDeviceAddress;
	bda_camera			: VkDeviceAddress;
}

Draw_Command :: struct {
	draw 				: VkDrawIndexedIndirectCommand;
    idx_transform		: u32;
    idx_material_instance   : u32;
}

Render_Transform :: struct {
	local_transform	: Matrix4;
	parent_idx		: u32;
	padding			: [12]u8;
}


AABB :: struct {
	center : Vector3; // The center of the box, NOT the world location
	pad0	: float;
	half_extents : Vector3;
	pad1	: float;
}

aabb_to_volume_bounds :: (aabb: *AABB) -> Volume_Bounds {
	return .{aabb.center - aabb.half_extents, aabb.center + aabb.half_extents};
}

Render_Globals :: struct {
	resolution_x	: u32;
	resolution_y	: u32;
	enable_panini	: bool;

}

Draw_Command_Buffers :: struct {
	bda_command_buffer_opaque 		: VkDeviceAddress;
	bda_command_buffer_translucent	: VkDeviceAddress;
	bda_command_buffer_emissive 	: VkDeviceAddress;
	bda_commands_debug_wireframe	: VkDeviceAddress;
} 