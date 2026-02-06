ImGui :: #import "ImGui";

IMGUI_VERT_ALLOC_SIZE	:: 1*1024*1024;
IMGUI_IDX_ALLOC_SIZE	:: 1*1024*1024;

ImGui_Push_Constants :: struct {
	scale             	: Vector2;
    translate         	: Vector2;  
    bda_vertex			: VkDeviceAddress;
	idx_font_texture	: u32;
}

UI_Pipeline_ImGui :: struct {
	pipeline 	: VkPipeline;
	layout		: VkPipelineLayout;

	build :: (using self: *UI_Pipeline_ImGui, zr: *ZRenderer) {
		success : bool;
		umgui_shader_vert : VkShaderModule;
		success, umgui_shader_vert = create_shader_module(zr, "src/shaders/ui/imgui.vert.spv");
		if !success {
			print("Error: Failed to create ImGui vertex shader\n");
			debug_break();
		}
		umgui_shader_frag : VkShaderModule;
		success, umgui_shader_frag = create_shader_module(zr, "src/shaders/ui/imgui.frag.spv");
		if !success {
			print("Error: Failed to create ImGui fragment shader\n");
			debug_break();
		}

		matrix_range : VkPushConstantRange;
		matrix_range.offset = 0;
		matrix_range.size = size_of(ImGui_Push_Constants);
		matrix_range.stageFlags = .VK_SHADER_STAGE_VERTEX_BIT | .VK_SHADER_STAGE_FRAGMENT_BIT;

		layouts := VkDescriptorSetLayout.[
           	zr.image_array_layout,      
        	zr.sampler_array_layout,    
        ];

		imgui_layout_info : VkPipelineLayoutCreateInfo = vkinit_pipeline_layout_create_info();
		imgui_layout_info.setLayoutCount = 2;
		imgui_layout_info.pSetLayouts = layouts.data;
		imgui_layout_info.pPushConstantRanges = *matrix_range;
		imgui_layout_info.pushConstantRangeCount = 1;

		new_layout : VkPipelineLayout;
		result := vkCreatePipelineLayout(zr.device, *imgui_layout_info, null, *new_layout);
		if result != .VK_SUCCESS {
			panic("Failed to create ImGui layout");
		}
		layout = new_layout;
		queue_deletion(*GLOBAL_DELETION_QUEUE, zr.device, layout);

		pipeline_builder : Pipeline_Builder;
		pipeline_builder.set_shaders(*pipeline_builder, umgui_shader_vert, umgui_shader_frag);
		
		pipeline_builder.set_input_topology(*pipeline_builder, .VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST);
		pipeline_builder.set_polygon_mode(*pipeline_builder, .VK_POLYGON_MODE_FILL);
		pipeline_builder.set_cull_mode(*pipeline_builder, .VK_CULL_MODE_NONE, .VK_FRONT_FACE_COUNTER_CLOCKWISE);
		pipeline_builder.set_multisampling_none(*pipeline_builder);
		pipeline_builder.enable_blending_alphablend(*pipeline_builder);
		pipeline_builder.disable_depthtest(*pipeline_builder);

		pipeline_builder.set_color_attachment_format(*pipeline_builder, zr.panini_image.image_format);
		pipeline_builder.set_vk_object_name(*pipeline_builder, "ImGui Pipeline");

		pipeline_builder.pipeline_layout = new_layout;

		pipeline = pipeline_builder.build(*pipeline_builder, zr);
		if pipeline == VK_NULL_HANDLE {
			panic("Failed to create ImGui pipeline");
		}

		vkDestroyShaderModule(zr.device, umgui_shader_vert, null);
		vkDestroyShaderModule(zr.device, umgui_shader_frag, null);
	}
}

ImGui_System :: struct {
	m_imgui				: UI_Pipeline_ImGui;

	vertex_buffer		: Staged_Array_Buffer;
	index_buffer		: Staged_Array_Buffer;

	font_image			: Allocated_Image;

	show_metrics		: bool;
	show_rendering		: bool;
}

imgui_active :: () -> bool {
	using ZRENDERER.imgui_system;
	return show_metrics || show_rendering || GAME_INSTANCE.menu_state != .NONE; // TODO: remove these when proper UI is in
}

initialize_imgui :: (using self: *ImGui_System, zr: *ZRenderer) {
	m_imgui.build(*m_imgui, zr);

	ImGui.CreateContext();
	ImGui.StyleColorsDark();

	vertex_buffer = make_staged_array_buffer(VMA_ALLOCATOR, IMGUI_VERT_ALLOC_SIZE, size_of(ImGui.ImDrawVert),
										.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT | .VK_BUFFER_USAGE_TRANSFER_DST_BIT | .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, 
										zr.device, "ImGui Vertex Buffer");
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, *vertex_buffer);

	index_buffer = make_staged_array_buffer(VMA_ALLOCATOR, IMGUI_IDX_ALLOC_SIZE, size_of(ImGui.ImDrawIdx),
									.VK_BUFFER_USAGE_INDEX_BUFFER_BIT | .VK_BUFFER_USAGE_TRANSFER_DST_BIT | .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, 
									zr.device, "ImGui Index Buffer");
	queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, *index_buffer);


	io := ImGui.GetIO();
	io.Fonts.AddFontDefault(io.Fonts);
	build := io.Fonts.Build(io.Fonts);
	if !build {
		return;
	}

	pixels: *u8;
	width, height : s32;
	io.Fonts.GetTexDataAsRGBA32(io.Fonts, *pixels, *width, *height);

	font_image = create_image(zr, pixels, VkExtent3D.{xx width, xx height, 1}, .VK_FORMAT_R8G8B8A8_UNORM, .VK_IMAGE_USAGE_SAMPLED_BIT, false, 0, "Image_ImGui_Font");
	font_image.image_index = xx zr.descriptor_writer.write_image(*zr.descriptor_writer, *zr.image_descriptor_buffer, font_image.image_view, .VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL);
	font_image.image_name = "imgui_font_image";
	table_add(*zr.image_table, font_image.image_name, font_image);
	
	io.Fonts.TexID = cast(ImGui.ImTextureID) font_image.image_index;
}

imgui_begin_frame :: (extents: Vector2) {
	io := ImGui.GetIO();
	io.DisplaySize = extents;
	ImGui.NewFrame();
}

imgui_tick :: () {
	using GAME_INSTANCE;
	using ImGui;

	if !imgui_active() {
		return;
	}

	if player_controller.current_selection.count != 0 {
		if Begin("Ship", flags = .AlwaysAutoResize) {
			entity := player_controller.current_selection[0];

			pos := get_entity_component(*get_active_game_world().world, entity, Position).value;
			Text(sprint("Position: %", pos));
			rot := get_entity_component(*get_active_game_world().world, entity, Rotation).value;
			Text(tprint("Rotation: %", rot));
			scale := get_entity_component(*get_active_game_world().world, entity, Scale).value;
			Text(sprint("Scale: %", scale));

			thrust := get_entity_component(*get_active_game_world().world, entity, Thrust);
			VSliderFloat("Thrust", .{40,150}, *thrust.value, 0, 10);
			SameLine();
			rot_velocity := get_entity_component(*get_active_game_world().world, entity, Rotational_Velocity);
			VSliderFloat("Torque", .{40,150}, *rot_velocity.value.z, -1, 1);
		}
		End();
	}

	if ZRENDERER.imgui_system.show_rendering {
		if Begin("Rendering", flags = .AlwaysAutoResize){
			if TreeNode("Panini Projection") {
				SliderFloat("Strength", *ZRENDERER.panini_parameters.strength, 0, 1);
				SliderFloat("Vertical Squeeze", *ZRENDERER.panini_parameters.squeeze, 0, 1);
				TreePop();
			}
			if TreeNode("Debug Views") {
				RadioButton("None", cast(*s32)*ZRENDERER.debug_system.view_mode, 0);
				RadioButton("Wireframe", cast(*s32)*ZRENDERER.debug_system.view_mode, 1);
				RadioButton("Light Cluster", cast(*s32)*ZRENDERER.debug_system.view_mode, 2);
				{
					if ZRENDERER.debug_system.view_mode == .LIGHT_CLUSTER {
						Indent();
						RadioButton("Depth Slice", cast(*s32)*ZRENDERER.debug_system.light_cluster_mode, 1); SameLine();
						RadioButton("Depth Rainbow", cast(*s32)*ZRENDERER.debug_system.light_cluster_mode, 2); SameLine();
						RadioButton("Screen UV", cast(*s32)*ZRENDERER.debug_system.light_cluster_mode, 3); SameLine();
						RadioButton("Heatmap", cast(*s32)*ZRENDERER.debug_system.light_cluster_mode, 4);
					}
					else ZRENDERER.debug_system.light_cluster_mode = 0;
				}

				TreePop();
			}
			if TreeNode("Visualizations") {
				if TreeNode("Lights") {
					Checkbox("Radius Sphere", *ZRENDERER.debug_system.light_radius_sphere);
					TreePop();
				}
				if TreeNode("Meshes") {
					Checkbox("AABB", *ZRENDERER.debug_system.mesh_aabb);
					TreePop();
				}
				if TreeNode("Spatialization") {
					Checkbox("BVH", *ZRENDERER.debug_system.bvh_bounds);
					TreePop();
				}
				TreePop();
			}
		}
		End();
	}
	
	if ZRENDERER.imgui_system.show_metrics {
		if Begin("Performance", flags = .AlwaysAutoResize) {
			Text(sprint("FPS: %", GAME_INSTANCE.fps));
			Text(tprint("%", GAME_INSTANCE.delta_time));
			Text(sprint("CurrentFrame: %", GAME_INSTANCE.current_frame));
		}
		End();
	} 
}

imgui_populate_buffers :: (using self: *ImGui_System, zr: *ZRenderer) {
	vertex_buffer.reset(*vertex_buffer);
    index_buffer.reset(*index_buffer);
    
    draw_data := ImGui.GetDrawData();
    for i: 0..draw_data.CmdListsCount-1 {
        cmd_list := draw_data.CmdLists[i];
        for j: 0..cmd_list.VtxBuffer.Size-1 {
            vertex_buffer.allocate(*vertex_buffer, cmd_list.VtxBuffer.Data[j]);
        }
        for j: 0..cmd_list.IdxBuffer.Size-1 {
            index_buffer.allocate(*index_buffer, cmd_list.IdxBuffer.Data[j]);
        }
    }
}

imgui_draw :: (using self: *ImGui_System, zr: *ZRenderer, cmd: VkCommandBuffer) {
	draw_data : *ImGui.ImDrawData = ImGui.GetDrawData();

	viewport : VkViewport;
	viewport.x = 0;
	viewport.y = 0;
	viewport.width = xx,no_check zr.draw_extent.width;
	viewport.height = xx,no_check zr.draw_extent.height;
	viewport.minDepth = 0;
	viewport.maxDepth = 1;

	vkCmdSetViewport(cmd, 0, 1, *viewport);

	bindings := VkDescriptorBufferBindingInfoEXT.[
		.{
			sType = .VK_STRUCTURE_TYPE_DESCRIPTOR_BUFFER_BINDING_INFO_EXT,
			address = zr.image_descriptor_buffer.base_address, // Use same as the rest of the rendering
			usage = .VK_BUFFER_USAGE_RESOURCE_DESCRIPTOR_BUFFER_BIT_EXT,
		},
		.{
			sType = .VK_STRUCTURE_TYPE_DESCRIPTOR_BUFFER_BINDING_INFO_EXT,
			address = zr.sampler_descriptor_buffer.base_address,
			usage = .VK_BUFFER_USAGE_SAMPLER_DESCRIPTOR_BUFFER_BIT_EXT,
		},
	];
	vkCmdBindDescriptorBuffersEXT(cmd, 2, bindings.data);

	buffer_indices : [2]u32 = .[0, 1];
	offsets : [2]VkDeviceSize = .[0, 0];
	vkCmdSetDescriptorBufferOffsetsEXT(cmd, .VK_PIPELINE_BIND_POINT_GRAPHICS,
		m_imgui.layout,  // Any material's layout works they all use same descriptor layout
		0, 2, buffer_indices.data, offsets.data);


	vkCmdBindIndexBuffer(cmd, index_buffer.device_buffer.buffer, 0, .VK_INDEX_TYPE_UINT16);

	vkCmdBindPipeline(cmd, .VK_PIPELINE_BIND_POINT_GRAPHICS, m_imgui.pipeline);

	push: ImGui_Push_Constants;
	push.scale = .{2.0 / draw_data.DisplaySize.x, 2.0 / draw_data.DisplaySize.y};
	push.translate = .{-1.0, -1.0};
	push.bda_vertex = vertex_buffer.device_buffer.base_address;
	push.idx_font_texture = font_image.image_index;
	vkCmdPushConstants(cmd, m_imgui.layout, .VK_SHADER_STAGE_VERTEX_BIT | .VK_SHADER_STAGE_FRAGMENT_BIT, 0, size_of(ImGui_Push_Constants), *push);

	global_vertex_offset: s32 = 0;
	global_index_offset: u32 = 0;
	for i: 0..draw_data.CmdListsCount-1 {
		cmd_list : *ImGui.ImDrawList = draw_data.CmdLists[i];

		for j: 0..cmd_list.CmdBuffer.Size-1 {
			draw_cmd : *ImGui.ImDrawCmd = *cmd_list.CmdBuffer.Data[j];
			
			if draw_cmd.UserCallback {
				draw_cmd.UserCallback(cmd_list, draw_cmd);
				continue;
			}

			clip_rect := draw_cmd.ClipRect; // x1, y1, x2, y2 format according to API
			view_clip := Vector4.{
									clip_rect.x - draw_data.DisplayPos.x, 
									clip_rect.y - draw_data.DisplayPos.y, 
									clip_rect.z - draw_data.DisplayPos.x, 
									clip_rect.w - draw_data.DisplayPos.y,}; 
			width := view_clip.z - view_clip.x;
			height := view_clip.w - view_clip.y;

			// Set dynamic viewport and scissor
			
			scissor : VkRect2D;
			scissor.offset.x = xx,no_check view_clip.x;
			scissor.offset.y = xx,no_check view_clip.y;
			scissor.extent.width = xx,no_check width;
			scissor.extent.height = xx,no_check height;

			vkCmdSetScissor(cmd, 0, 1, *scissor);

			vert_offset := draw_cmd.VtxOffset;
			index_offset := draw_cmd.IdxOffset;

			vkCmdDrawIndexed(cmd, draw_cmd.ElemCount, 1, global_index_offset + index_offset, xx,no_check (xx,no_check global_vertex_offset + vert_offset), 0);
		}
		global_vertex_offset += cmd_list.VtxBuffer.Size;
   		global_index_offset += xx,no_check cmd_list.IdxBuffer.Size;
	}
}

imgui_transfer_buffers :: (using self: *ImGui_System, cmd: VkCommandBuffer) {
	vertex_buffer.transfer(*vertex_buffer, cmd);
	index_buffer.transfer(*index_buffer, cmd);
}

imgui_process_SDL_event :: (event: *SDL_Event) {
    io := ImGui.GetIO();

    if event.type == {
        case SDL_MOUSEMOTION;
            io.MousePos = ImGui.ImVec2.{xx event.motion.x, xx event.motion.y};
            
        case SDL_MOUSEBUTTONDOWN;
            if event.button.button == SDL_BUTTON_LEFT   io.MouseDown[0] = true;
            if event.button.button == SDL_BUTTON_RIGHT  io.MouseDown[1] = true;
            if event.button.button == SDL_BUTTON_MIDDLE io.MouseDown[2] = true;
            
        case SDL_MOUSEBUTTONUP;
            if event.button.button == SDL_BUTTON_LEFT   io.MouseDown[0] = false;
            if event.button.button == SDL_BUTTON_RIGHT  io.MouseDown[1] = false;
            if event.button.button == SDL_BUTTON_MIDDLE io.MouseDown[2] = false;
            
        case SDL_MOUSEWHEEL;
            io.MouseWheel = xx event.wheel.y;
            
        case SDL_TEXTINPUT;
            io.AddInputCharactersUTF8(io, xx, no_check event.text.text.data);
            
        case SDL_KEYDOWN; #through;
        case SDL_KEYUP;
            key := event.key.keysym.scancode;
            io.KeysDown[key] = (event.type == SDL_KEYDOWN);
            
            mods := SDL_GetModState();
            io.KeyCtrl  = (mods & KMOD_CTRL) != 0;
            io.KeyShift = (mods & KMOD_SHIFT) != 0;
            io.KeyAlt   = (mods & KMOD_ALT) != 0;
    }
}