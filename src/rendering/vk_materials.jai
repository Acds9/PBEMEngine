MATERIAL_CONSTANTS_BUFFER_SIZE 			:: 8*1024*1024; // 8MB, probably overkill

MATERIAL_PASS :: enum u8 {
	MAIN_COLOR 		:: 0;
}

Material_Pool :: struct {
	constants_buffer	: Storage_Buffer;

	init :: (using self: *Material_Pool, device: VkDevice, allocator: VmaAllocator, constants_buffer_size: u64) {
		constants_buffer = make_storage_buffer(VMA_ALLOCATOR, constants_buffer_size, .VK_BUFFER_USAGE_TRANSFER_SRC_BIT | .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, .VMA_MEMORY_USAGE_CPU_TO_GPU, device, "constants_buffer buffer");
		queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, constants_buffer.buffer, constants_buffer.allocation);
	}

	allocate_material_constants :: (using self: *Material_Pool, data: *void, size: u32) -> VkDeviceAddress {
		return constants_buffer.allocate(*constants_buffer, data, size);
	}
}

Material_Pipeline :: struct {
	pipeline 	: VkPipeline;
	layout		: VkPipelineLayout;
}

Material_Instance :: struct {
	pipeline			: Material_Pipeline;
	pass_type			: MATERIAL_PASS;

	constants_address 	: VkDeviceAddress;

	color_texture_index		: u32;
}

Material_Opaque :: struct {
	pipeline : Material_Pipeline;

	Material_Constants :: struct {
		color_factors		: Vector4;
		padding				: [15]Vector4; // For uniform buffers
	}

	Material_Resources :: struct {
		color_image			: Allocated_Image;
		data_address		: VkDeviceAddress;
	}

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
		pipeline.layout = new_layout;
		queue_deletion(*GLOBAL_DELETION_QUEUE, zr.device, pipeline.layout);

		pipeline_builder : Pipeline_Builder;
		pipeline_builder.set_shaders(*pipeline_builder, mesh_vert_shader, mesh_frag_shader);
		pipeline_builder.set_input_topology(*pipeline_builder, .VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST);
		pipeline_builder.set_polygon_mode(*pipeline_builder, .VK_POLYGON_MODE_FILL);
		pipeline_builder.set_cull_mode(*pipeline_builder, .VK_CULL_MODE_NONE, .VK_FRONT_FACE_CLOCKWISE);
		pipeline_builder.set_multisampling_none(*pipeline_builder);
		pipeline_builder.disable_blending(*pipeline_builder);
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

	create_material_instance :: (using self: *Material_Opaque, zr: *ZRenderer, pass: MATERIAL_PASS, constants: *Material_Opaque.Material_Constants, resources: *Material_Resources) -> Material_Instance {
		mat_data : Material_Instance;
		mat_data.pass_type = pass;
		mat_data.pipeline = *pipeline;		
		mat_data.constants_address = zr.material_pool.allocate_material_constants(*zr.material_pool, *constants, size_of(Material_Opaque.Material_Constants));

		mat_data.color_texture_index = xx zr.descriptor_writer.write_image(*zr.descriptor_writer, *zr.image_descriptor_buffer, resources.color_image.image_view, .VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL);

		return mat_data;
	}

}

