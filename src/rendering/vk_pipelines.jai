/*
init_background_pipelines :: (zr: *ZRenderer) -> bool, string {
	compute_layout : VkPipelineLayoutCreateInfo;
	compute_layout.sType = .VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
	compute_layout.pSetLayouts = *zr.draw_image_desc_layout;
	compute_layout.setLayoutCount = 1;

	result := vkCreatePipelineLayout(zr.device, *compute_layout, null, *zr.gradient_pipeline_layout);
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

	result = vkCreateComputePipelines(zr.device, null, 1, *compute_pipeline_create_info, null, *zr.gradient_pipeline);
	if result != .VK_SUCCESS {
		return false, sprint("%\n", result); 
	}

	// Shader module has been used and can be deleted already
	vkDestroyShaderModule(zr.device, compute_draw_shader, null);
	// Rest has to go at deinit
	array_add(*GLOBAL_DELETION_QUEUE.pipelines, .{zr.device, zr.gradient_pipeline});
	array_add(*GLOBAL_DELETION_QUEUE.pipeline_layouts, .{zr.device, zr.gradient_pipeline_layout});

	return true, "";
}*/

init_mesh_pipeline :: (zr: *ZRenderer) {
	zr.opaque_material.build(*zr.opaque_material, zr);
}
