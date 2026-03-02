#import "Basic";
#import "Random";
#import "Math";
#import "GL";
#import "SDL";
#import "Input";
#import "mimalloc";

GAME_VERSION :: "0.0.1";

// Here instead of in game_world.jai due to the ghastly multi-phase build system
// TODO: Build system really needs a full rewrite soon
create_game_world :: (name: string, type: World_Type) -> Game_World {
	game_world : Game_World;
	game_world.type = type;
	game_world.name = name; 
	game_world.world = create_world(type);
	game_world.scene = create_scene(VMA_ALLOCATOR, ZRENDERER.device);
	return game_world;
}

destroy :: (using self: *Game_World) {
	destroy(*world);
	destroy(*scene);
	memset(self, 0, size_of(Game_World));
}

Game_Instance :: struct {
	active_world		: Game_World;
    quit				: bool;

	player_controller 	: Player_Controller;

	menu_state			: MENU_STATE;

	simulation_system	: Simulation_System;
	replay_system		: Replay_System;
    // Timing
    frequency			: u64;
    last_counter		: u64;
	delta_time 			: float32;
    fps					: u32;
	current_frame 		: u64;

	input_system 		: Input_System;

	lane_system 		: Lane_System;
}

GAME_INSTANCE : Game_Instance;

WINDOW_WIDTH 	:= 1920;
WINDOW_HEIGHT 	:= 1080;

// Not really constants but only 1 will ever exist
ZRENDERER 				: ZRenderer;
VMA_ALLOCATOR 			: VmaAllocator;
GLOBAL_DELETION_QUEUE 	: Deletion_Queue;

MOUSELOOK_SENSITIVITY	: float = 1;
CAMERA_MOVESPEED		: float = 25;

mi_allocator :: Allocator.{
    proc = (mode: Allocator_Mode, size: s64, old_size: s64, old_ptr: *void, data: *void) -> *void {
        if mode == {
            case .ALLOCATE;   return mi_malloc(cast(u64)size);
            case .RESIZE;     return mi_realloc(old_ptr, cast(u64)size);
            case .FREE;       mi_free(old_ptr); return null;
        }
        return null;
    },
    data = null
};

game_init :: () -> bool {
	using GAME_INSTANCE;
	
    // Renderer setup
    init_success, init_error := init_zrenderer(*ZRENDERER);
    if !init_success {
        print("ERROR: %\n", init_error);
        return false;
    }
	load_all_meshes(*ZRENDERER); // TODO: this is temporary
    
	enter_main_menu();

    // Input setup
    SDL_SetRelativeMouseMode(SDL_TRUE);
    SDL_SetHint(SDL_HINT_MOUSE_RELATIVE_MODE_WARP, "1");
	initialize_input_system(*input_system);
    
    // Timing
    frequency = SDL_GetPerformanceFrequency();
    last_counter = SDL_GetPerformanceCounter();
    
	GAME_INSTANCE.menu_state = .MAIN;
	toggle_mouse_input_mode(*GAME_INSTANCE.input_system);
    return true;
}

enter_main_menu :: () {
	using GAME_INSTANCE;
	active_world = create_game_world("main_menu", .MAIN_MENU);

	GAME_INSTANCE.menu_state = .MAIN;
}

window_handle_sdl_event :: (event: *SDL_Event) {
	using GAME_INSTANCE;
	if event.type== {
		case SDL_QUIT;
			quit = true;
		case SDL_KEYUP;
			if event.key.keysym.sym == SDLK_ESCAPE {
				if active_world.type== {
					case .REPLAY; {
						quit_replay();
					}
					case .MAIN_MENU; {
						if menu_state == .MAIN {
							quit = true;
						}
						else {
							menu_state = .MAIN;
						}
					}
				}
			} 
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

game_render :: (using game_world: *Game_World) {
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
	WakeAllConditionVariable(*GAME_INSTANCE.lane_system.barrier.cond); // Make sure to release any thread stuck on barrier
    vkDeviceWaitIdle(ZRENDERER.device);
	destroy(*GAME_INSTANCE.active_world); 
    deinit_zrenderer(*ZRENDERER);
}

process_input :: (event: *SDL_Event) {
	input_begin_frame(*GAME_INSTANCE.input_system);
	io := ImGui.GetIO();

	while SDL_PollEvent(event) {
		// Always forward to ImGui so it can track hover/focus state
		imgui_process_SDL_event(event);

		is_mouse_event := event.type == SDL_MOUSEMOTION || event.type == SDL_MOUSEBUTTONDOWN
					   || event.type == SDL_MOUSEBUTTONUP || event.type == SDL_MOUSEWHEEL;
		is_key_event   := event.type == SDL_KEYDOWN || event.type == SDL_KEYUP
					   || event.type == SDL_TEXTINPUT;

		// Skip game input when ImGui wants to consume the event
		if (is_mouse_event && io.WantCaptureMouse) || (is_key_event && io.WantCaptureKeyboard) {
			window_handle_sdl_event(event);
			continue;
		}

		input_handle_sdl_event(*GAME_INSTANCE.input_system, event);
		window_handle_sdl_event(event);
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
	if get_command(*GAME_INSTANCE.input_system, .MOUSE_BUTTON_LEFT).key_down {
		if GAME_INSTANCE.input_system.current_mode == .MOUSE_MODE {
			x, y : s32;
			SDL_GetMouseState(*x, *y);
			origin, dir := screen_to_ray(x, y, xx,no_check ZRENDERER.resolution.width, xx,no_check ZRENDERER.resolution.height, *ZRENDERER.camera.gpu_data.view_proj);
			debug_draw_line(*ZRENDERER, origin, origin + dir*50000, .{1,0,0,1}, 500);
			hit, entity := trace_ray(*GAME_INSTANCE.active_world.scene.bvh_system, origin, dir);

			if hit {
				player_controller_set_selection(*GAME_INSTANCE.player_controller, entity);
			} else {
				player_controller_clear_selection(*GAME_INSTANCE.player_controller);
			}
		}
	}
	tick_input_commands(*GAME_INSTANCE.input_system, xx,no_check GAME_INSTANCE.delta_time);
}

game_loop :: () {
	event: SDL_Event;
	while !GAME_INSTANCE.quit {
		narrow(#code{
			// Update timing
			current_counter := SDL_GetPerformanceCounter();
			GAME_INSTANCE.delta_time = cast,no_check(float32)(current_counter - GAME_INSTANCE.last_counter) / 
							GAME_INSTANCE.frequency;
			GAME_INSTANCE.fps = cast,no_check(u32)(1 / GAME_INSTANCE.delta_time);
			GAME_INSTANCE.last_counter = current_counter;
			GAME_INSTANCE.current_frame += 1;

			imgui_begin_frame(.{xx,no_check ZRENDERER.draw_extent.width, xx,no_check ZRENDERER.draw_extent.height});
			
			process_input(*event);
			player_controller_tick(*GAME_INSTANCE.player_controller, *GAME_INSTANCE.active_world);
       		game_update_camera();

			if GAME_INSTANCE.menu_state != .NONE {
				draw_main_menu();
			}
			imgui_tick();
			
			game_render(*GAME_INSTANCE.active_world);
		});
		barrier_wait(context.lane_barrier);
		
		simulate_pending_sims();
		
		if GAME_INSTANCE.active_world.type == .MAIN_MENU {
			// Menu tick? Maybe later when we have a real UI system
		} else if GAME_INSTANCE.active_world.type == .REPLAY {
			tick_replay(*GAME_INSTANCE.active_world, GAME_INSTANCE.delta_time);
		}
		
		barrier_wait(context.lane_barrier);
    }
}

main :: () {
	context.allocator = mi_allocator;
//	mi_option_enable(.SHOW_STATS);   // Stats on exit
//  mi_option_enable(.VERBOSE);      // Detailed logging

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