MATERIAL_PASS :: enum u8 {
	MAIN_COLOR 		:: 0;
	BLACKBODY		:: 1;
}

Material_Pipeline :: struct {
	pipeline 	: VkPipeline;
	layout		: VkPipelineLayout;
}

Material_Instance :: struct {
	pipeline		: Material_Pipeline;
	material_set	: VkDescriptorSet;
	pass_type		: MATERIAL_PASS;
}

Material_Opaque :: struct {
	pipeline : Material_Pipeline;
	layout : VkDescriptorSetLayout;

	Material_Constants :: struct {
		color_factors		: Vector4;
		blackbody_factors	: Vector4;
		padding				: [14]Vector4; // For uniform buffers
	}

	Material_Resources :: struct {
		color_image			: Allocated_Image;
		color_sampler		: VkSampler;
		blackbody_image		: Allocated_Image;
		blackbody_sampler	: VkSampler;
		data_buffer			: VkBuffer;
		data_buffer_offset 	: u32;
	}

	writer : Descriptor_Writer;

	build :: (using self: *Material_Opaque, zr: *ZRenderer) {
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
		matrix_range.stageFlags = .VK_SHADER_STAGE_VERTEX_BIT;

		layout_builder : Descriptor_Layout_Builder;
		layout_builder.add_binding(*layout_builder, 0, .VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER);
		layout_builder.add_binding(*layout_builder, 1, .VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER);
		layout_builder.add_binding(*layout_builder, 2, .VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER);

		success, _, layout = layout_builder.build(*layout_builder, zr.device, .VK_SHADER_STAGE_VERTEX_BIT | .VK_SHADER_STAGE_FRAGMENT_BIT);


		layouts : [2]VkDescriptorSetLayout = .[zr.gpu_scene_data_desc_layout, layout];

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
		pipeline.layout = new_layout;
		queue_deletion(*GLOBAL_DELETION_QUEUE, zr.device, pipeline.layout);
		queue_deletion(*GLOBAL_DELETION_QUEUE, zr.device, layout);

		pipeline_builder : Pipeline_Builder;
		pipeline_builder.set_shaders(*pipeline_builder, mesh_vert_shader, mesh_frag_shader);
		pipeline_builder.set_input_topology(*pipeline_builder, .VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST);
		pipeline_builder.set_polygon_mode(*pipeline_builder, .VK_POLYGON_MODE_FILL);
		pipeline_builder.set_cull_mode(*pipeline_builder, .VK_CULL_MODE_NONE, .VK_FRONT_FACE_CLOCKWISE);
		pipeline_builder.set_multisampling_none(*pipeline_builder, );
		pipeline_builder.disable_blending(*pipeline_builder, );
		pipeline_builder.enable_depthtest(*pipeline_builder, true, .VK_COMPARE_OP_GREATER_OR_EQUAL);

		pipeline_builder.set_color_attachment_format(*pipeline_builder, zr.draw_image.image_format);
		pipeline_builder.set_depth_format(*pipeline_builder, zr.depth_image.image_format);
		pipeline_builder.set_vk_object_name(*pipeline_builder, "Opaque Pipeline");

		pipeline_builder.pipeline_layout = new_layout;

		pipeline.pipeline = pipeline_builder.build(*pipeline_builder, zr);
		if pipeline.pipeline == VK_NULL_HANDLE {
			panic("Failed to create opaque pipeline");
		}

		vkDestroyShaderModule(zr.device, mesh_frag_shader, null);
		vkDestroyShaderModule(zr.device, mesh_vert_shader, null);
	}

	clear_resources :: (using self: *Material_Opaque, device: VkDevice) {
		
	}

	write_material :: (using self: *Material_Opaque, device: VkDevice, pass: MATERIAL_PASS, resources: *Material_Resources, descriptor_allocator: *Descriptor_Allocator) -> Material_Instance {
		mat_data : Material_Instance;
		mat_data.pass_type = pass;

		mat_data.pipeline = *pipeline;
		
		mat_data.material_set = descriptor_allocator.allocate(descriptor_allocator, device, layout);

		writer.clear(*writer);
		writer.write_buffer(*writer, 0, resources.data_buffer, size_of(Material_Constants), resources.data_buffer_offset, .VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER);
		writer.write_image(*writer, 1, resources.color_image.image_view, resources.color_sampler,  .VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL, .VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER);
		writer.write_image(*writer, 2, resources.blackbody_image.image_view, resources.blackbody_sampler, .VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL, .VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER);

		return mat_data;
	}

}

