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
	current_frame : u64;

	input_system : Input_System;
	mouse_mode : bool;

	lane_system : Lane_System;
}

GAME_INSTANCE : Game_Instance;

WINDOW_WIDTH 	:= 1920;
WINDOW_HEIGHT 	:= 1080;

// Not really constants but only 1 will ever exist
ZRENDERER 				: ZRenderer;
VMA_ALLOCATOR 			: VmaAllocator;
GLOBAL_DELETION_QUEUE 	: Deletion_Queue;

MOUSELOOK_SENSITIVITY	: float = 1;
CAMERA_MOVESPEED		: float = 10;

game_init :: () -> bool {
	using GAME_INSTANCE;
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

window_handle_sdl_event :: (event: *SDL_Event) {
	using GAME_INSTANCE;
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

game_update_camera :: () {
	using GAME_INSTANCE;
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

game_tick :: () {
	using GAME_INSTANCE;
	{
		execute_Query_Update_Render_Proxy(*GAME_INSTANCE.world, #code {
			transform := Transform.{position.pos, rotation.rot, scale.scale};
			matrix := transform_to_matrix4(transform);
			idx := mesh_render_proxy_ec.idx_mesh_instance;
				
			mesh_instance := render_get_mesh_instance(*GAME_INSTANCE.scene, idx);
			render_set_transform(*GAME_INSTANCE.scene, idx, *matrix);
		});
	}
	// Separate this into a debug tick, it's just easier to keep it single threaded
	if context.thread_index == 0 {
		ZRENDERER.debug_system.reset(*ZRENDERER.debug_system);
	
		if ZRENDERER.debug_system.light_radius_sphere {
			execute_Query_Debug_Draw_Point_Light(*GAME_INSTANCE.world, #code {
				debug_draw_point(*ZRENDERER, position.pos, 5, point_light_component.color); 
				debug_draw_sphere(*ZRENDERER, position.pos, point_light_component.radius, point_light_component.color);
			});
		}
	}
	tick_world(*world, delta_time);
}

game_render :: () {
	using GAME_INSTANCE;
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

game_shutdown :: () {
	using GAME_INSTANCE;
    vkDeviceWaitIdle(ZRENDERER.device);
    deinit_zrenderer(*ZRENDERER);
	WakeAllConditionVariable(*GAME_INSTANCE.lane_system.barrier.cond); // Make sure to release any thread stuck on barrier
    // Add world cleanup later
}

game_loop :: () {
	event: SDL_Event;
	while !GAME_INSTANCE.quit {
		if context.thread_index == 0 {
			// Update timing
			current_counter := SDL_GetPerformanceCounter();
			GAME_INSTANCE.delta_time = cast,no_check(float64)(current_counter - GAME_INSTANCE.last_counter) / 
							cast,no_check(float64)GAME_INSTANCE.frequency;
			GAME_INSTANCE.fps = cast,no_check(u32)(1 / GAME_INSTANCE.delta_time);
			GAME_INSTANCE.last_counter = current_counter;
			GAME_INSTANCE.current_frame += 1;
			imgui_begin_frame(.{xx,no_check ZRENDERER.draw_extent.width, xx,no_check ZRENDERER.draw_extent.height});
			input_begin_frame(*GAME_INSTANCE.input_system);
        
			// Process input
			while SDL_PollEvent(*event) {
				if imgui_active() {
					imgui_process_SDL_event(*event);
				}

				input_handle_sdl_event(*GAME_INSTANCE.input_system, *event);
				window_handle_sdl_event(*event);
			}

			if get_command(*GAME_INSTANCE.input_system, .TOGGLE_MOUSE_MODE).key_down {
				toggle_mouse_input_mode(*GAME_INSTANCE.input_system);
			}
			if get_command(*GAME_INSTANCE.input_system, .TOGGLE_IMGUI_DEBUG_METRICS).key_down {
				ZRENDERER.imgui_system.show_metrics = !ZRENDERER.imgui_system.show_metrics;
			}
			if get_command(*GAME_INSTANCE.input_system, .TOGGLE_IMGUI_DEBUG_RENDERING).key_down {
				ZRENDERER.imgui_system.show_rendering = !ZRENDERER.imgui_system.show_rendering;
			}
			tick_input_commands(*GAME_INSTANCE.input_system, xx,no_check GAME_INSTANCE.delta_time);

			 // Update camera from input
       		game_update_camera();
		}
       	barrier_wait(context.lane_barrier);
       
		scene_tick(*GAME_INSTANCE.scene);
        game_tick();
		barrier_wait(context.lane_barrier);

		if context.thread_index == 0 {
			imgui_tick();
			game_render();
		}
		barrier_wait(context.lane_barrier);
    }
}

main :: () {
	GAME_INSTANCE.lane_system.init(*GAME_INSTANCE.lane_system);
	// Lanes enter into game_loop, so this sets up lane 0 which is default (thread_index is already 0)
	context.lane_count = GAME_INSTANCE.lane_system.lane_count;
    context.lane_barrier = *GAME_INSTANCE.lane_system.barrier;

    if !game_init() {
        return;
    }
	
	// And we call the same that the lanes are told to run
	game_loop();

    game_shutdown();
}