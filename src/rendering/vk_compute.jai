LIGHT_CLUSTER_NUM_WIDTH 	:: 32;
LIGHT_CLUSTER_NUM_HEIGHT 	:: 16;
LIGHT_CLUSTER_NUM_DEPTH		:: 24;
MAX_LIGHTS_PER_CLUSTER		:: 32; // Anything after this is discarded

Light_Clustering_Push_Constants :: struct {
	render_globals			: VkDeviceAddress;
	camera_data_address		: VkDeviceAddress;
	point_light_address		: VkDeviceAddress;
	cluster_buffer_address	: VkDeviceAddress;
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
// TODO: it crashes when exiting the mesh, not when looking at light?
Light_Cluster_System :: struct {
	m_c_light_cluster 		: Compute_Pipeline_Light_Clustering;
	
	light_cluster_buffer_0	: Uniform_Storage_Buffer;
	light_cluster_buffer_1	: Uniform_Storage_Buffer;

	init :: (using self: *Light_Cluster_System, zr: *ZRenderer, resolution: VkExtent2D) {
		m_c_light_cluster.build(*m_c_light_cluster, zr);

		cluster_count : u64 = LIGHT_CLUSTER_NUM_WIDTH * LIGHT_CLUSTER_NUM_HEIGHT * LIGHT_CLUSTER_NUM_DEPTH;
		cluster_buffer_size : u64 = cluster_count * size_of(Light_Cluster);
		print("CLUSTER COUNT: %\n", cluster_count);
		light_cluster_buffer_0 = make_uniform_storage_buffer(VMA_ALLOCATOR, cluster_buffer_size, size_of(Light_Cluster), .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT | .VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | .VK_BUFFER_USAGE_TRANSFER_DST_BIT, .GPU_ONLY,
																	zr.device, "frame 0 light_cluster buffer");
		queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, *light_cluster_buffer_0);

		light_cluster_buffer_1 = make_uniform_storage_buffer(VMA_ALLOCATOR, cluster_buffer_size, size_of(Light_Cluster), .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT | .VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | .VK_BUFFER_USAGE_TRANSFER_DST_BIT, .GPU_ONLY,
																	zr.device, "frame 1 light_cluster buffer");
		queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, *light_cluster_buffer_1);
	}

	get_frame_buffer :: (using self: *Light_Cluster_System, frame: u8) -> *Uniform_Storage_Buffer {
		if frame == 0 {
			return *light_cluster_buffer_0;
		}
		else {
			return *light_cluster_buffer_1;
		}
	}
}