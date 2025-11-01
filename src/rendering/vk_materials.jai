MATERIAL_CONSTANTS_BUFFER_SIZE 			:: 8*1024*1024; // 8MB, probably overkill

Material_Type :: enum {
    OPAQUE;
    TRANSPARENT;
    EMISSIVE;
	ADDITIVE;
}

MATERIAL_PASS :: enum u8 {
	MAIN_COLOR 		:: 0;
}

Material_Pool :: struct {
	constants_buffer	: Storage_Buffer;

	init :: (using self: *Material_Pool, device: VkDevice, allocator: VmaAllocator, constants_buffer_size: u64) {
		constants_buffer = make_storage_buffer(VMA_ALLOCATOR, constants_buffer_size, .VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, .VMA_MEMORY_USAGE_CPU_TO_GPU, device, "constants_buffer buffer");
		queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, constants_buffer.buffer, constants_buffer.allocation);
	}

	allocate_material_constants :: (using self: *Material_Pool, data: *void, size: u32) -> VkDeviceAddress {
		return constants_buffer.allocate(*constants_buffer, data, size);
	}
}

Material_Instance :: struct {
	pipeline 			: VkPipeline;
	layout				: VkPipelineLayout;
	pass_type			: MATERIAL_PASS;

	constants_address 	: VkDeviceAddress;
}

Material_Constants_Debug_Point :: struct {
	color_factors			: Vector4;
}

Material_Constants_Debug_Wireframe :: struct {
	color_factors			: Vector4;
}

Material_Constants_Opaque :: struct {
	color_factors			: Vector4;
	albedo_image_index		: u32;
	albedo_sampler_index 	: u32;
}

Material_Constants :: struct {
	union {
		point		: Material_Constants_Debug_Point;
		wireframe	: Material_Constants_Debug_Wireframe;
		opaque 		: Material_Constants_Opaque;
	}
}

Material_Pipeline_Debug_Point :: struct {
	pipeline 	: VkPipeline;
	layout		: VkPipelineLayout;

	build :: (using self: *Material_Pipeline_Debug_Point, zr: *ZRenderer) {
		success : bool;
		point_vert_shader : VkShaderModule;
		success, point_vert_shader = create_shader_module(zr, "src/shaders/debug_point.vert.spv");
		if !success {
			panic("Error: Failed to create debug_point vertex shader");
		}
		point_frag_shader : VkShaderModule;
		success, point_frag_shader = create_shader_module(zr, "src/shaders/debug_point.frag.spv");
		if !success {
			panic("Error: Failed to create debug_point fragment shader");
		}
		
		matrix_range : VkPushConstantRange;
		matrix_range.offset = 0;
		matrix_range.size = size_of(Debug_Draw_Push_Constants);
		matrix_range.stageFlags = .VK_SHADER_STAGE_VERTEX_BIT | .VK_SHADER_STAGE_FRAGMENT_BIT;

		mesh_layout_info : VkPipelineLayoutCreateInfo = vkinit_pipeline_layout_create_info();
		mesh_layout_info.setLayoutCount = 0;
		mesh_layout_info.pSetLayouts = null;
		mesh_layout_info.pPushConstantRanges = *matrix_range;
		mesh_layout_info.pushConstantRangeCount = 1;

		new_layout : VkPipelineLayout;
		result := vkCreatePipelineLayout(zr.device, *mesh_layout_info, null, *new_layout);
		if result != .VK_SUCCESS {
			panic("Failed to create Material_Pipeline_Debug_Point layout");
		}
		layout = new_layout;
		queue_deletion(*GLOBAL_DELETION_QUEUE, zr.device, layout);

		pipeline_builder : Pipeline_Builder;
		pipeline_builder.set_shaders(*pipeline_builder, point_vert_shader, point_frag_shader);
		pipeline_builder.set_input_topology(*pipeline_builder, .VK_PRIMITIVE_TOPOLOGY_POINT_LIST);
		pipeline_builder.set_polygon_mode(*pipeline_builder, .VK_POLYGON_MODE_FILL);
		pipeline_builder.set_cull_mode(*pipeline_builder, .VK_CULL_MODE_NONE, .VK_FRONT_FACE_COUNTER_CLOCKWISE);
		pipeline_builder.set_line_width(*pipeline_builder, 1);
		pipeline_builder.set_multisampling_none(*pipeline_builder);
		pipeline_builder.disable_blending(*pipeline_builder);
		pipeline_builder.enable_depthtest(*pipeline_builder, true, .VK_COMPARE_OP_LESS_OR_EQUAL);

		pipeline_builder.set_color_attachment_format(*pipeline_builder, zr.draw_image.image_format);
		pipeline_builder.set_depth_format(*pipeline_builder, zr.depth_image.image_format);
		pipeline_builder.set_vk_object_name(*pipeline_builder, "Debug Shapes Pipeline");

		pipeline_builder.pipeline_layout = new_layout;

		pipeline = pipeline_builder.build(*pipeline_builder, zr);
		if pipeline == VK_NULL_HANDLE {
			panic("Failed to create debug point pipeline");
		}

		vkDestroyShaderModule(zr.device, point_vert_shader, null);
		vkDestroyShaderModule(zr.device, point_frag_shader, null);
	}

	clear_resources :: (using self: *Material_Pipeline_Debug_Point, device: VkDevice) {
		
	}

	create_material_instance :: (using self: *Material_Pipeline_Debug_Point, zr: *ZRenderer, pass: MATERIAL_PASS, constants: *Material_Constants_Debug_Point) -> Material_Instance {
		mat_data : Material_Instance;
		mat_data.pass_type = pass;
		mat_data.pipeline = pipeline;	
		mat_data.layout = layout;
		mat_data.constants_address = zr.material_pool.allocate_material_constants(*zr.material_pool, constants, size_of(Material_Constants_Debug_Point));
		return mat_data;
	}
}

Material_Pipeline_Debug_Wireframe :: struct {
	pipeline 	: VkPipeline;
	layout		: VkPipelineLayout;

	build :: (using self: *Material_Pipeline_Debug_Wireframe, zr: *ZRenderer) {
		success : bool;
		wireframe_frag_shader : VkShaderModule;
		success, wireframe_frag_shader = create_shader_module(zr, "src/shaders/debug_wireframe.frag.spv");
		if !success {
			panic("Error: Failed to create debug_wireframe fragment shader");
		}
		wireframe_vert_shader : VkShaderModule;
		success, wireframe_vert_shader = create_shader_module(zr, "src/shaders/debug_wireframe.vert.spv");
		if !success {
			panic("Error: Failed to create debug_wireframe vertex shader");
		}

		matrix_range : VkPushConstantRange;
		matrix_range.offset = 0;
		matrix_range.size = size_of(GPU_Draw_Push_Constants);
		matrix_range.stageFlags = .VK_SHADER_STAGE_VERTEX_BIT | .VK_SHADER_STAGE_FRAGMENT_BIT;

		layouts := VkDescriptorSetLayout.[
            zr.image_array_layout,      
            zr.sampler_array_layout,    
        ];

		mesh_layout_info : VkPipelineLayoutCreateInfo = vkinit_pipeline_layout_create_info();
		mesh_layout_info.setLayoutCount = 2;
		mesh_layout_info.pSetLayouts = layouts.data;
		mesh_layout_info.pPushConstantRanges = *matrix_range;
		mesh_layout_info.pushConstantRangeCount = 1;

		new_layout : VkPipelineLayout;
		result := vkCreatePipelineLayout(zr.device, *mesh_layout_info, null, *new_layout);
		if result != .VK_SUCCESS {
			panic("Failed to create Material_Wireframe layout");
		}
		layout = new_layout;
		queue_deletion(*GLOBAL_DELETION_QUEUE, zr.device, layout);

		pipeline_builder : Pipeline_Builder;
		pipeline_builder.set_shaders(*pipeline_builder, wireframe_vert_shader, wireframe_frag_shader);
		pipeline_builder.set_input_topology(*pipeline_builder, .VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST);
		pipeline_builder.set_polygon_mode(*pipeline_builder, .VK_POLYGON_MODE_LINE);
		pipeline_builder.set_cull_mode(*pipeline_builder, .VK_CULL_MODE_NONE, .VK_FRONT_FACE_COUNTER_CLOCKWISE);
		pipeline_builder.set_line_width(*pipeline_builder, 1);
		pipeline_builder.set_multisampling_none(*pipeline_builder);
		pipeline_builder.disable_blending(*pipeline_builder);
		pipeline_builder.enable_depthtest(*pipeline_builder, true, .VK_COMPARE_OP_LESS_OR_EQUAL);

		pipeline_builder.set_color_attachment_format(*pipeline_builder, zr.draw_image.image_format);
		pipeline_builder.set_depth_format(*pipeline_builder, zr.depth_image.image_format);
		pipeline_builder.set_vk_object_name(*pipeline_builder, "Debug Wireframe Pipeline");

		pipeline_builder.pipeline_layout = new_layout;

		pipeline = pipeline_builder.build(*pipeline_builder, zr);
		if pipeline == VK_NULL_HANDLE {
			panic("Failed to create debug wireframe pipeline");
		}

		vkDestroyShaderModule(zr.device, wireframe_frag_shader, null);
		vkDestroyShaderModule(zr.device, wireframe_vert_shader, null);
	}

	clear_resources :: (using self: *Material_Pipeline_Debug_Wireframe, device: VkDevice) {
		
	}

	create_material_instance :: (using self: *Material_Pipeline_Debug_Wireframe, zr: *ZRenderer, pass: MATERIAL_PASS, constants: *Material_Constants_Debug_Wireframe) -> Material_Instance {
		mat_data : Material_Instance;
		mat_data.pass_type = pass;
		mat_data.pipeline = pipeline;	
		mat_data.layout = layout;
		mat_data.constants_address = zr.material_pool.allocate_material_constants(*zr.material_pool, constants, size_of(Material_Constants_Debug_Wireframe));
		return mat_data;
	}
}

Material_Pipeline_Opaque :: struct {
	pipeline 	: VkPipeline;
	layout		: VkPipelineLayout;

	build :: (using self: *Material_Pipeline_Opaque, zr: *ZRenderer) {
		success : bool;
		mesh_frag_shader : VkShaderModule;
		success, mesh_frag_shader = create_shader_module(zr, "src/shaders/mesh.frag.spv");
		if !success {
			print("Error: Failed to create mesh fragment shader\n");
			debug_break();
		}
		mesh_vert_shader : VkShaderModule;
		success, mesh_vert_shader = create_shader_module(zr, "src/shaders/mesh.vert.spv");
		if !success {
			print("Error: Failed to create mesh vertex shader\n");
			debug_break();
		}

		matrix_range : VkPushConstantRange;
		matrix_range.offset = 0;
		matrix_range.size = size_of(GPU_Draw_Push_Constants);
		matrix_range.stageFlags = .VK_SHADER_STAGE_VERTEX_BIT | .VK_SHADER_STAGE_FRAGMENT_BIT;

		layouts := VkDescriptorSetLayout.[
            zr.image_array_layout,      
            zr.sampler_array_layout,    
        ];

		mesh_layout_info : VkPipelineLayoutCreateInfo = vkinit_pipeline_layout_create_info();
		mesh_layout_info.setLayoutCount = 2;
		mesh_layout_info.pSetLayouts = layouts.data;
		mesh_layout_info.pPushConstantRanges = *matrix_range;
		mesh_layout_info.pushConstantRangeCount = 1;

		new_layout : VkPipelineLayout;
		result := vkCreatePipelineLayout(zr.device, *mesh_layout_info, null, *new_layout);
		if result != .VK_SUCCESS {
			panic("Failed to create Material_Opaque layout");
		}
		layout = new_layout;
		queue_deletion(*GLOBAL_DELETION_QUEUE, zr.device, layout);

		pipeline_builder : Pipeline_Builder;
		pipeline_builder.set_shaders(*pipeline_builder, mesh_vert_shader, mesh_frag_shader);
		pipeline_builder.set_input_topology(*pipeline_builder, .VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST);
		pipeline_builder.set_polygon_mode(*pipeline_builder, .VK_POLYGON_MODE_FILL);
		pipeline_builder.set_cull_mode(*pipeline_builder, .VK_CULL_MODE_BACK_BIT, .VK_FRONT_FACE_COUNTER_CLOCKWISE);
		pipeline_builder.set_multisampling_none(*pipeline_builder);
		pipeline_builder.disable_blending(*pipeline_builder);
		pipeline_builder.enable_depthtest(*pipeline_builder, true, .VK_COMPARE_OP_LESS_OR_EQUAL);

		pipeline_builder.set_color_attachment_format(*pipeline_builder, zr.draw_image.image_format);
		pipeline_builder.set_depth_format(*pipeline_builder, zr.depth_image.image_format);
		pipeline_builder.set_vk_object_name(*pipeline_builder, "Opaque Pipeline");

		pipeline_builder.pipeline_layout = new_layout;

		pipeline = pipeline_builder.build(*pipeline_builder, zr);
		if pipeline == VK_NULL_HANDLE {
			panic("Failed to create opaque pipeline");
		}

		vkDestroyShaderModule(zr.device, mesh_frag_shader, null);
		vkDestroyShaderModule(zr.device, mesh_vert_shader, null);
	}

	clear_resources :: (using self: *Material_Pipeline_Opaque, device: VkDevice) {
		
	}

	create_material_instance :: (using self: *Material_Pipeline_Opaque, zr: *ZRenderer, pass: MATERIAL_PASS, constants: *Material_Constants_Opaque) -> Material_Instance {
		mat_data : Material_Instance;
		mat_data.pass_type = pass;
		mat_data.pipeline = pipeline;	
		mat_data.layout = layout;
		mat_data.constants_address = zr.material_pool.allocate_material_constants(*zr.material_pool, constants, size_of(Material_Constants_Opaque));
		return mat_data;
	}

}