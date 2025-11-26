FLATTENED_TRANSFORM_BUFFER_SIZE :: 8*1024*1024; //8MB?

Transform_Flatten_Push_Constants :: struct {
	bda_transforms			: VkDeviceAddress;
	bda_flattened_transforms: VkDeviceAddress;
	transform_count			: u32;
}

Compute_Pipeline_Transform_Flatten :: struct {
	pipeline 	: VkPipeline;
	layout		: VkPipelineLayout;

	build :: (using self: *Compute_Pipeline_Transform_Flatten, zr: *ZRenderer) {
		success : bool;
		transform_flatten_shader : VkShaderModule;
		success, transform_flatten_shader = create_shader_module(zr, "src/shaders/transform_flatten.comp.spv");
		if !success {
			panic("Error: Failed to create mesh_culling_shader compute shader");
		}
		
		push_range : VkPushConstantRange;
		push_range.offset = 0;
		push_range.size = size_of(Transform_Flatten_Push_Constants);
		push_range.stageFlags = .VK_SHADER_STAGE_COMPUTE_BIT;

		layout_info : VkPipelineLayoutCreateInfo = vkinit_pipeline_layout_create_info();
		layout_info.setLayoutCount = 0;
		layout_info.pSetLayouts = null;
		layout_info.pPushConstantRanges = *push_range;
		layout_info.pushConstantRangeCount = 1;

		new_layout : VkPipelineLayout;
		result := vkCreatePipelineLayout(zr.device, *layout_info, null, *new_layout);
		if result != .VK_SUCCESS {
			panic("Failed to create Compute_Pipeline_Transform_Flatten layout");
		}
		layout = new_layout;
		queue_deletion(*GLOBAL_DELETION_QUEUE, zr.device, layout);

		// Compute pipeline
        stage_info : VkPipelineShaderStageCreateInfo;
        stage_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        stage_info.stage = .VK_SHADER_STAGE_COMPUTE_BIT;
        stage_info.module = transform_flatten_shader;
        stage_info.pName = "main";

        compute_pipeline_info : VkComputePipelineCreateInfo;
        compute_pipeline_info.sType = .VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO;
        compute_pipeline_info.stage = stage_info;
        compute_pipeline_info.layout = layout;

        result = vkCreateComputePipelines(zr.device, VK_NULL_HANDLE, 1, *compute_pipeline_info, null, *pipeline);
        if result != .VK_SUCCESS {
            panic("Failed to create Compute_Pipeline_Transform_Flatten compute pipeline");
        }
        queue_deletion(*GLOBAL_DELETION_QUEUE, zr.device, pipeline);

		vkDestroyShaderModule(zr.device, transform_flatten_shader, null);
	}
}

Mesh_Culling_Push_Constants :: struct {
	bda_render_globals		: VkDeviceAddress;
	bda_camera				: VkDeviceAddress;
	bda_mesh_instances		: VkDeviceAddress;
	bda_flattened_transforms: VkDeviceAddress;
	bda_aabb				: VkDeviceAddress;
	bda_geo_surfaces		: VkDeviceAddress;
	bda_material_instances	: VkDeviceAddress;
	bda_draw_address_buffer : VkDeviceAddress;
	mesh_instance_count		: u32;
}

Compute_Pipeline_Mesh_Culling :: struct {
	pipeline 	: VkPipeline;
	layout		: VkPipelineLayout;

	build :: (using self: *Compute_Pipeline_Mesh_Culling, zr: *ZRenderer) {
		success : bool;
		mesh_culling_shader : VkShaderModule;
		success, mesh_culling_shader = create_shader_module(zr, "src/shaders/mesh_culling.comp.spv");
		if !success {
			panic("Error: Failed to create mesh_culling_shader compute shader");
		}
		
		push_range : VkPushConstantRange;
		push_range.offset = 0;
		push_range.size = size_of(Mesh_Culling_Push_Constants);
		push_range.stageFlags = .VK_SHADER_STAGE_COMPUTE_BIT;

		layout_info : VkPipelineLayoutCreateInfo = vkinit_pipeline_layout_create_info();
		layout_info.setLayoutCount = 0;
		layout_info.pSetLayouts = null;
		layout_info.pPushConstantRanges = *push_range;
		layout_info.pushConstantRangeCount = 1;

		new_layout : VkPipelineLayout;
		result := vkCreatePipelineLayout(zr.device, *layout_info, null, *new_layout);
		if result != .VK_SUCCESS {
			panic("Failed to create Compute_Pipeline_Mesh_Culling layout");
		}
		layout = new_layout;
		queue_deletion(*GLOBAL_DELETION_QUEUE, zr.device, layout);

		// Specialization Constants
		spec_entries: [2] VkSpecializationMapEntry;
		spec_entries[0] = .{ constantID = 0, offset = 0, size = size_of(float) }; // Near Z
		spec_entries[1] = .{ constantID = 1, offset = 4, size = size_of(float) }; // Far Z


		spec_data: struct {
			z_near		: float = NEAR_PLANE;
			z_far		: float = FAR_PLANE;
		};

		spec_info := VkSpecializationInfo.{
			mapEntryCount = spec_entries.count,
			pMapEntries = spec_entries.data,
			dataSize = size_of(type_of(spec_data)),
			pData = *spec_data,
		};

		// Compute pipeline
        stage_info : VkPipelineShaderStageCreateInfo;
        stage_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        stage_info.stage = .VK_SHADER_STAGE_COMPUTE_BIT;
        stage_info.module = mesh_culling_shader;
		stage_info.pSpecializationInfo = *spec_info;
        stage_info.pName = "main";

        compute_pipeline_info : VkComputePipelineCreateInfo;
        compute_pipeline_info.sType = .VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO;
        compute_pipeline_info.stage = stage_info;
        compute_pipeline_info.layout = layout;

        result = vkCreateComputePipelines(zr.device, VK_NULL_HANDLE, 1, *compute_pipeline_info, null, *pipeline);
        if result != .VK_SUCCESS {
            panic("Failed to create Compute_Pipeline_Mesh_Culling compute pipeline");
        }
        queue_deletion(*GLOBAL_DELETION_QUEUE, zr.device, pipeline);

		vkDestroyShaderModule(zr.device, mesh_culling_shader, null);
	}
}

Mesh_Compute_System :: struct {
	m_c_transform_flatten			: Compute_Pipeline_Transform_Flatten;
	flattened_transform_buffer		: [2]Allocated_Buffer; // These are GPU side so we don't need fancy buffer types

	m_c_mesh_culling	 		: Compute_Pipeline_Mesh_Culling;
	
	init :: (using self: *Mesh_Compute_System, zr: *ZRenderer) {
		for *buffer: flattened_transform_buffer {
			<<buffer = create_buffer(VMA_ALLOCATOR, FLATTENED_TRANSFORM_BUFFER_SIZE, 
															.VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT | .VK_BUFFER_USAGE_STORAGE_BUFFER_BIT,
															.GPU_ONLY, zr.device, sprint("frame % flattened_transform buffer", it_index));
			queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, buffer);
		}

		m_c_transform_flatten.build(*m_c_transform_flatten, zr);
		m_c_mesh_culling.build(*m_c_mesh_culling, zr);
	}

	get_frame_transform_buffer :: (using self: *Mesh_Compute_System, frame: u8) -> *Allocated_Buffer {
		return *flattened_transform_buffer[frame];
	}
}

Light_Culling_Push_Constants :: struct {
	bda_render_globals		: VkDeviceAddress;
	bda_camera				: VkDeviceAddress;
	bda_point_lights		: VkDeviceAddress;
	bda_light_bitfield		: VkDeviceAddress;
	point_light_count		: u32;
}

Compute_Pipeline_Light_Culling :: struct {
	pipeline 	: VkPipeline;
	layout		: VkPipelineLayout;

	build :: (using self: *Compute_Pipeline_Light_Culling, zr: *ZRenderer) {
		success : bool;
		light_culling_shader : VkShaderModule;
		success, light_culling_shader = create_shader_module(zr, "src/shaders/light_culling.comp.spv");
		if !success {
			panic("Error: Failed to create light_culling_shader compute shader");
		}
		
		push_range : VkPushConstantRange;
		push_range.offset = 0;
		push_range.size = size_of(Light_Culling_Push_Constants);
		push_range.stageFlags = .VK_SHADER_STAGE_COMPUTE_BIT;

		layout_info : VkPipelineLayoutCreateInfo = vkinit_pipeline_layout_create_info();
		layout_info.setLayoutCount = 0;
		layout_info.pSetLayouts = null;
		layout_info.pPushConstantRanges = *push_range;
		layout_info.pushConstantRangeCount = 1;

		new_layout : VkPipelineLayout;
		result := vkCreatePipelineLayout(zr.device, *layout_info, null, *new_layout);
		if result != .VK_SUCCESS {
			panic("Failed to create Compute_Pipeline_Light_Culling layout");
		}
		layout = new_layout;
		queue_deletion(*GLOBAL_DELETION_QUEUE, zr.device, layout);

		// Specialization Constants
		spec_entries: [2] VkSpecializationMapEntry;
		spec_entries[0] = .{ constantID = 0, offset = 0, size = size_of(float) }; // Near Z
		spec_entries[1] = .{ constantID = 1, offset = 4, size = size_of(float) }; // Far Z


		spec_data: struct {
			z_near		: float = NEAR_PLANE;
			z_far		: float = FAR_PLANE;
		};

		spec_info := VkSpecializationInfo.{
			mapEntryCount = spec_entries.count,
			pMapEntries = spec_entries.data,
			dataSize = size_of(type_of(spec_data)),
			pData = *spec_data,
		};

		// Compute pipeline
        stage_info : VkPipelineShaderStageCreateInfo;
        stage_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        stage_info.stage = .VK_SHADER_STAGE_COMPUTE_BIT;
        stage_info.module = light_culling_shader;
		stage_info.pSpecializationInfo = *spec_info;
        stage_info.pName = "main";

        compute_pipeline_info : VkComputePipelineCreateInfo;
        compute_pipeline_info.sType = .VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO;
        compute_pipeline_info.stage = stage_info;
        compute_pipeline_info.layout = layout;

        result = vkCreateComputePipelines(zr.device, VK_NULL_HANDLE, 1, *compute_pipeline_info, null, *pipeline);
        if result != .VK_SUCCESS {
            panic("Failed to create Compute_Pipeline_Light_Culling compute pipeline");
        }
        queue_deletion(*GLOBAL_DELETION_QUEUE, zr.device, pipeline);

		vkDestroyShaderModule(zr.device, light_culling_shader, null);
	}
}

LIGHT_CLUSTER_NUM_WIDTH 	:: 32;
LIGHT_CLUSTER_NUM_HEIGHT 	:: 16;
LIGHT_CLUSTER_NUM_DEPTH		:: 24;
MAX_LIGHTS_PER_CLUSTER		:: 32; // Anything after this is discarded

Light_Clustering_Push_Constants :: struct {
	bda_render_globals		: VkDeviceAddress;
	bda_camera				: VkDeviceAddress;
	bda_point_lights		: VkDeviceAddress;
	bda_clusters			: VkDeviceAddress;
	bda_light_bitfield		: VkDeviceAddress;
	point_light_count 		: u32;
}

Light_Cluster :: struct {
	light_indices 	: [MAX_LIGHTS_PER_CLUSTER]u32;
}

Compute_Pipeline_Light_Clustering :: struct {
	pipeline 	: VkPipeline;
	layout		: VkPipelineLayout;

	build :: (using self: *Compute_Pipeline_Light_Clustering, zr: *ZRenderer) {
		success : bool;
		light_clustering_shader : VkShaderModule;
		success, light_clustering_shader = create_shader_module(zr, "src/shaders/light_cluster.comp.spv");
		if !success {
			panic("Error: Failed to create light_clustering_shader compute shader");
		}
		
		push_range : VkPushConstantRange;
		push_range.offset = 0;
		push_range.size = size_of(Light_Clustering_Push_Constants);
		push_range.stageFlags = .VK_SHADER_STAGE_COMPUTE_BIT;

		layout_info : VkPipelineLayoutCreateInfo = vkinit_pipeline_layout_create_info();
		layout_info.setLayoutCount = 0;
		layout_info.pSetLayouts = null;
		layout_info.pPushConstantRanges = *push_range;
		layout_info.pushConstantRangeCount = 1;

		new_layout : VkPipelineLayout;
		result := vkCreatePipelineLayout(zr.device, *layout_info, null, *new_layout);
		if result != .VK_SUCCESS {
			panic("Failed to create Compute_Pipeline_Light_Clustering layout");
		}
		layout = new_layout;
		queue_deletion(*GLOBAL_DELETION_QUEUE, zr.device, layout);

		// Specialization Constants
		spec_entries: [6] VkSpecializationMapEntry;
		spec_entries[0] = .{ constantID = 0, offset = 0, 	size = size_of(u32) };
		spec_entries[1] = .{ constantID = 1, offset = 4, 	size = size_of(u32) };
		spec_entries[2] = .{ constantID = 2, offset = 8, 	size = size_of(u32) };
		spec_entries[3] = .{ constantID = 3, offset = 12, 	size = size_of(float) };
		spec_entries[4] = .{ constantID = 4, offset = 16, 	size = size_of(float) };
		spec_entries[5] = .{ constantID = 5, offset = 20, 	size = size_of(u32) };

		spec_data: struct {
			cluster_x	: u32 = LIGHT_CLUSTER_NUM_WIDTH;
			cluster_y	: u32 = LIGHT_CLUSTER_NUM_HEIGHT;
			cluster_z	: u32 = LIGHT_CLUSTER_NUM_DEPTH;
			z_near		: float = NEAR_PLANE;
			z_far		: float = FAR_PLANE;
			cluster_light_num	: u32 = MAX_LIGHTS_PER_CLUSTER;
		};

		spec_info := VkSpecializationInfo.{
			mapEntryCount = spec_entries.count,
			pMapEntries = spec_entries.data,
			dataSize = size_of(type_of(spec_data)),
			pData = *spec_data,
		};

		// Compute pipeline
        stage_info : VkPipelineShaderStageCreateInfo;
        stage_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        stage_info.stage = .VK_SHADER_STAGE_COMPUTE_BIT;
        stage_info.module = light_clustering_shader;
		stage_info.pSpecializationInfo = *spec_info;
        stage_info.pName = "main";

        compute_pipeline_info : VkComputePipelineCreateInfo;
        compute_pipeline_info.sType = .VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO;
        compute_pipeline_info.stage = stage_info;
        compute_pipeline_info.layout = layout;

        result = vkCreateComputePipelines(zr.device, VK_NULL_HANDLE, 1, *compute_pipeline_info, null, *pipeline);
        if result != .VK_SUCCESS {
            panic("Failed to create Compute_Pipeline_Light_Clustering compute pipeline");
        }
        queue_deletion(*GLOBAL_DELETION_QUEUE, zr.device, pipeline);

		vkDestroyShaderModule(zr.device, light_clustering_shader, null);
	}
}

Light_Compute_System :: struct {
	m_c_light_culling			: Compute_Pipeline_Light_Culling;
	light_culling_bitfield		: [2]Bitfield_Buffer;
	
	m_c_light_cluster 			: Compute_Pipeline_Light_Clustering;
	light_cluster_buffer		: [2]Uniform_Storage_Buffer;
	
	init :: (using self: *Light_Compute_System, zr: *ZRenderer) {
		m_c_light_culling.build(*m_c_light_culling, zr);
		for *buffer: light_culling_bitfield {
			<<buffer = make_bitfield_buffer(VMA_ALLOCATOR, MAX_LIGHTS, 
														.VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT | .VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | .VK_BUFFER_USAGE_TRANSFER_DST_BIT,
														.GPU_ONLY, zr.device, sprint("frame % light_culling bitfield", it_index));
			queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, buffer);
		}

		m_c_light_cluster.build(*m_c_light_cluster, zr);
		cluster_count : u64 = LIGHT_CLUSTER_NUM_WIDTH * LIGHT_CLUSTER_NUM_HEIGHT * LIGHT_CLUSTER_NUM_DEPTH;
		cluster_buffer_size : u64 = cluster_count * size_of(Light_Cluster);
		for *buffer: light_cluster_buffer {
			<<buffer = make_uniform_storage_buffer(VMA_ALLOCATOR, cluster_buffer_size, size_of(Light_Cluster), .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT | .VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | .VK_BUFFER_USAGE_TRANSFER_DST_BIT, 
																	.GPU_ONLY,
																	zr.device, sprint("frame % light_cluster buffer", it_index));
			queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, buffer);
		}
	}

	get_frame_buffer :: (using self: *Light_Compute_System, frame: u8) -> *Uniform_Storage_Buffer {
		return *light_cluster_buffer[frame];
	}

	get_frame_light_bitfield :: (using self: *Light_Compute_System, frame: u8) -> *Bitfield_Buffer {
		return *light_culling_bitfield[frame];
	}
}