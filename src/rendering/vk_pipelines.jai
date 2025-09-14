
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

init_mesh_pipeline :: (zr: *ZRenderer) {
	success : bool;
	triangle_frag_shader : VkShaderModule; 
	success, triangle_frag_shader = create_shader_module(zr, "src/shaders/tex_image.frag.spv");
	if !success {
		print("Error: Failed to create triangle fragment shader\n");
		debug_break();
	}

	triangle_vert_shader : VkShaderModule;
	success, triangle_vert_shader = create_shader_module(zr, "src/shaders/colored_triangle_mesh.vert.spv");
	if !success {
		print("Error: Failed to create triangle vertex shader\n");
		debug_break();
	}
	
	buffer_range : VkPushConstantRange;
	buffer_range.size = size_of(GPU_Draw_Push_Constants);
	buffer_range.stageFlags = .VK_SHADER_STAGE_VERTEX_BIT;
	
	pipeline_layout_info : VkPipelineLayoutCreateInfo = vkinit_pipeline_layout_create_info();
	pipeline_layout_info.pPushConstantRanges = *buffer_range;
	pipeline_layout_info.pushConstantRangeCount = 1;
	pipeline_layout_info.pSetLayouts = *zr.image_descriptor_layout;
	pipeline_layout_info.setLayoutCount = 1;
	
	result := vkCreatePipelineLayout(zr.logical_device, *pipeline_layout_info, null, *zr.mesh_pipeline_layout);
	if result != .VK_SUCCESS {
		print("Error: Failed to create mesh pipeline with error: %\n", result);
		debug_break();
	}

	builder : Pipeline_Builder;
	builder.pipeline_layout = zr.mesh_pipeline_layout;
	builder.set_shaders(*builder, triangle_vert_shader, triangle_frag_shader);
	builder.set_input_topology(*builder,.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST);
	builder.set_polygon_mode(*builder,.VK_POLYGON_MODE_FILL);
	builder.set_cull_mode(*builder,.VK_CULL_MODE_NONE, .VK_FRONT_FACE_CLOCKWISE);
	builder.set_multisampling_none(*builder);
	builder.disable_blending(*builder);
	builder.enable_depthtest(*builder, true, .VK_COMPARE_OP_GREATER_OR_EQUAL);

	builder.set_color_attachment_format(*builder,zr.draw_image.image_format);
	builder.set_depth_format(*builder,zr.depth_image.image_format);

	builder.set_vk_object_name(*builder, "Mesh Pipeline");
	
	zr.mesh_pipeline = builder.build(*builder, zr.logical_device);

	set_vk_object_name(zr.logical_device, .PIPELINE, cast(u64)zr.mesh_pipeline, "Mesh Pipeline");
	set_vk_object_name(zr.logical_device, .PIPELINE_LAYOUT, cast(u64)zr.mesh_pipeline_layout, "Mesh Pipeline Layout");
	
	vkDestroyShaderModule(zr.logical_device, triangle_frag_shader, null);
	vkDestroyShaderModule(zr.logical_device, triangle_vert_shader, null);

	array_add(*zr.deletion_queue.pipeline_layouts, .{zr.logical_device, zr.mesh_pipeline_layout});
	array_add(*zr.deletion_queue.pipelines, .{zr.logical_device, zr.mesh_pipeline});
}