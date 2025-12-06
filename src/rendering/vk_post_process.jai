Panini_Push_Constants :: struct {
	fov             : float;
    d               : float;  // panini strength
    s               : float;  // vertical squeeze  
    aspect          : float;
    draw_image_idx  : u32;    // index into bindless image array
	sampler_idx     : u32;
}

Panini_Parameters :: struct {
	strength 	: float = 0.5;
	squeeze		: float = 0;
}

Post_Process_Pipeline_Panini :: struct {
	pipeline 	: VkPipeline;
	layout		: VkPipelineLayout;

	build :: (using self: *Post_Process_Pipeline_Panini, zr: *ZRenderer) {
		success : bool;
		panini_shader_vert : VkShaderModule;
		success, panini_shader_vert = create_shader_module(zr, "src/shaders/pp/panini.vert.spv");
		if !success {
			print("Error: Failed to create panini vertex shader\n");
			debug_break();
		}
		panini_shader_frag : VkShaderModule;
		success, panini_shader_frag = create_shader_module(zr, "src/shaders/pp/panini.frag.spv");
		if !success {
			print("Error: Failed to create panini fragment shader\n");
			debug_break();
		}

		matrix_range : VkPushConstantRange;
		matrix_range.offset = 0;
		matrix_range.size = size_of(Panini_Push_Constants);
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
		pipeline_builder.set_shaders(*pipeline_builder, panini_shader_vert, panini_shader_frag);
		
		pipeline_builder.set_input_topology(*pipeline_builder, .VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST);
		pipeline_builder.set_polygon_mode(*pipeline_builder, .VK_POLYGON_MODE_FILL);
		pipeline_builder.set_cull_mode(*pipeline_builder, .VK_CULL_MODE_NONE, .VK_FRONT_FACE_COUNTER_CLOCKWISE);
		pipeline_builder.set_multisampling_none(*pipeline_builder);
		pipeline_builder.disable_blending(*pipeline_builder);
		pipeline_builder.enable_depthtest(*pipeline_builder, false, .VK_COMPARE_OP_GREATER_OR_EQUAL);

		pipeline_builder.set_color_attachment_format(*pipeline_builder, zr.panini_image.image_format);
		pipeline_builder.set_vk_object_name(*pipeline_builder, "Panini Post-Process Pipeline");

		pipeline_builder.pipeline_layout = new_layout;

		pipeline = pipeline_builder.build(*pipeline_builder, zr);
		if pipeline == VK_NULL_HANDLE {
			panic("Failed to create opaque pipeline");
		}

		vkDestroyShaderModule(zr.device, panini_shader_vert, null);
		vkDestroyShaderModule(zr.device, panini_shader_frag, null);
	}
}

set_panini :: (zr: *ZRenderer, enable: bool) {
	rg := cast,no_check(*Render_Globals)zr.render_globals.staging_buffer.info.pMappedData;
	rg.enable_panini = enable;
}