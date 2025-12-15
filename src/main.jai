#import "Basic";
#import "Random";
#import "Math";
#import "GL";
#import "SDL";
#import "Input";

Game_Instance :: struct {
    world: ZWorld;
    scene: ZScene;
    quit: bool;
    
    // Timing
    frequency: u64;
    last_counter: u64;
    delta_time: float64;
    fps: u32;

	input_system : Input_System;
	mouse_mode : bool;

	// Debug
	imgui_mode : bool;
}

GAME_STATE : Game_Instance;

WINDOW_WIDTH 	:= 1920;
WINDOW_HEIGHT 	:= 1080;

// Not really constants but only 1 will ever exist
ZRENDERER 				: ZRenderer;
VMA_ALLOCATOR 			: VmaAllocator;
GLOBAL_DELETION_QUEUE 	: Deletion_Queue;

MOUSELOOK_SENSITIVITY	: float = 1;
CAMERA_MOVESPEED		: float = 10;

game_init :: (using state: *Game_Instance) -> bool {
	init_zworld(*world);

    // Renderer setup
    init_success, init_error := init_zrenderer(*ZRENDERER);
    if !init_success {
        print("ERROR: %\n", init_error);
        return false;
    }
	load_all_meshes(*ZRENDERER); // TODO: this is temporary
    
    // Scene setup
    scene = create_zscene(VMA_ALLOCATOR, ZRENDERER.device);

	create_entity_batch(*world, Archetype_Ship, 3); 

	light_entity := create_entity(*world, Archetype_Point_Light); 
	position := get_entity_component(*world, light_entity, Position);
	position.pos = .{1,1,20};
	light_component := get_entity_component(*world, light_entity, Point_Light_Component);
    light_component.radius = 16;
    light_component.color = .{.3,.3,1,1};

	light_entity_2 := create_entity(*world, Archetype_Point_Light); 
	position_2 := get_entity_component(*world, light_entity_2, Position);
	position_2.pos = .{1,1,32};
	light_component_2 := get_entity_component(*world, light_entity_2, Point_Light_Component);
    light_component_2.radius = 64;
    light_component_2.color = .{.3,1,.3,1};
	
    // Input setup
    SDL_SetRelativeMouseMode(SDL_TRUE);
    SDL_SetHint(SDL_HINT_MOUSE_RELATIVE_MODE_WARP, "1");
	initialize_input_system(*input_system);
    
    // Timing
    frequency = SDL_GetPerformanceFrequency();
    last_counter = SDL_GetPerformanceCounter();
    
    return true;
}

window_handle_sdl_event :: (using state: *Game_Instance, event: *SDL_Event) {
	if event.type == {
		case SDL_QUIT;
			quit = true;
		case SDL_KEYUP;
			if event.key.keysym.sym == SDLK_ESCAPE quit = true;
		case SDL_WINDOWEVENT;
			if event.window.event == SDL_WINDOWEVENT_MINIMIZED {
				ZRENDERER.minimized = true;
			}
			else if event.window.event == SDL_WINDOWEVENT_RESTORED {
				ZRENDERER.minimized = false;
			}
		case SDL_MOUSEMOTION;
			if input_system.current_mode == .MOUSE_MODE {
				return;
			}
			delta_x := cast,no_check(float) event.motion.xrel;
			delta_y := -cast,no_check(float) event.motion.yrel;

			sensitivity : float = cast,no_check(float)(MOUSELOOK_SENSITIVITY * delta_time);
			delta_yaw := make_rotor(.{0, 0, 1}, delta_x * sensitivity);
			delta_pitch := make_rotor(.{0, 1, 0}, -delta_y * sensitivity);

			ZRENDERER.camera.rotation = normalize(delta_yaw * ZRENDERER.camera.rotation * delta_pitch);
	}
}

game_update_camera :: (using state: *Game_Instance) {
    if get_command(*input_system, .MOVE_FORWARD).held {
        ZRENDERER.camera.translate(*ZRENDERER.camera, ZRENDERER.camera.forward * CAMERA_MOVESPEED * delta_time);
    }
    else if get_command(*input_system, .MOVE_BACKWARD).held {
        ZRENDERER.camera.translate(*ZRENDERER.camera, ZRENDERER.camera.forward * -CAMERA_MOVESPEED * delta_time);
    }

    if get_command(*input_system, .MOVE_RIGHT).held {
        ZRENDERER.camera.translate(*ZRENDERER.camera, ZRENDERER.camera.right * CAMERA_MOVESPEED * delta_time);
    }
    else if get_command(*input_system, .MOVE_LEFT).held {
        ZRENDERER.camera.translate(*ZRENDERER.camera, ZRENDERER.camera.right * -CAMERA_MOVESPEED * delta_time);
    }
	
	if get_command(*input_system, .MOVE_UP).held {
        ZRENDERER.camera.translate(*ZRENDERER.camera, ZRENDERER.camera.up * CAMERA_MOVESPEED * delta_time);
    }
    else if get_command(*input_system, .MOVE_DOWN).held {
        ZRENDERER.camera.translate(*ZRENDERER.camera, ZRENDERER.camera.up * -CAMERA_MOVESPEED * delta_time);
    }
}

toggle_imgui_mode :: (using state: *Game_Instance) {
	if imgui_mode == true {
		imgui_mode = false;
	}
	else {
		imgui_mode = true;
	}
}

current_position : Vector3;
game_tick :: (using state: *Game_Instance) {
	ZRENDERER.debug_system.reset(*ZRENDERER.debug_system);
	/*{
		execute_Query_Position_Randomizer(*GAME_STATE.world, #code {
			for *pos: position_array {
				if pos.pos == current_position {
					current_position += .{1000,0,0};
				}
				dir := pos.pos - current_position;
				norm := normalize(dir);
				//pos.pos -= norm*10*GAME_STATE.delta_time;
			}
		});
	}*/
	
	{
		execute_Query_Update_Render_Proxy(*GAME_STATE.world, #code {
			for *pos: position_array {
				rot := rotation_array[it_index];
				scale := scale_array[it_index];
				transform := Transform.{pos.pos, rot.rot, scale.scale};
				matrix := transform_to_matrix4(transform);
				idx := mesh_render_proxy_ec_array[it_index].idx_mesh_instance;
				
				mesh_instance := render_get_mesh_instance(*GAME_STATE.scene, idx);
				render_set_transform(*GAME_STATE.scene, idx, *matrix);
			}
		});
	}
	if ZRENDERER.debug_system.light_radius_sphere {
		execute_Query_Debug_Draw_Point_Light(*GAME_STATE.world, #code {
			for *pos: position_array {
				point_light := *point_light_component_array[it_index];
				position	:= *position_array[it_index].pos;
				debug_draw_point(*ZRENDERER, position, 5, point_light.color); 
				debug_draw_sphere(*ZRENDERER, position, point_light.radius, point_light.color);
			}
		});
	}
	
	tick_world(*world, delta_time);
}

game_render :: (using state: *Game_Instance) {
    if !ZRENDERER.minimized {
        draw_frame(*ZRENDERER, *scene);
    }
    else {
        sleep_milliseconds(50);
    }
    
    if ZRENDERER.resize_requested {
        resize_swapchain(*ZRENDERER);
    }
}

game_shutdown :: (using state: *Game_Instance) {
    vkDeviceWaitIdle(ZRENDERER.device);
    deinit_zrenderer(*ZRENDERER);
    // Add world cleanup later
}

main :: () {
    if !game_init(*GAME_STATE) {
        return;
    }

    event: SDL_Event;
    while !GAME_STATE.quit {
        // Update timing
        current_counter := SDL_GetPerformanceCounter();
        GAME_STATE.delta_time = cast,no_check(float64)(current_counter - GAME_STATE.last_counter) / 
                          cast,no_check(float64)GAME_STATE.frequency;
        GAME_STATE.fps = cast,no_check(u32)(1 / GAME_STATE.delta_time);
        GAME_STATE.last_counter = current_counter;

		imgui_begin_frame(.{xx,no_check ZRENDERER.draw_extent.width, xx,no_check ZRENDERER.draw_extent.height});
		input_begin_frame(*GAME_STATE.input_system);
        
        // Process input
        while SDL_PollEvent(*event) {
			if GAME_STATE.imgui_mode {
				imgui_process_SDL_event(*event);
			}

			input_handle_sdl_event(*GAME_STATE.input_system, *event);
            window_handle_sdl_event(*GAME_STATE, *event);
        }

		if get_command(*GAME_STATE.input_system, .TOGGLE_MOUSE_MODE).key_down {
       		toggle_mouse_input_mode(*GAME_STATE.input_system);
		}
		if get_command(*GAME_STATE.input_system, .TOGGLE_IMGUI_MODE).key_down {
			toggle_imgui_mode(*GAME_STATE);
		}
        tick_input_commands(*GAME_STATE.input_system, xx,no_check GAME_STATE.delta_time);

        // Update camera from input
        game_update_camera(*GAME_STATE);
        
        // Game tick
        game_tick(*GAME_STATE);

		// ImGui tick
		imgui_tick(*GAME_STATE);
        
        // Render
        game_render(*GAME_STATE);
    }
    
    game_shutdown(*GAME_STATE);
}