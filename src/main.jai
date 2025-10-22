#import "Basic";
#import "Random";
#import "Math";
#import "GL";
#import "SDL";
#import "Input";


Game_State :: struct {
    world: ZWorld;
    scene: ZScene;
    quit: bool;
    
    // Timing
    frequency: u64;
    last_counter: u64;
    delta_time: float64;
    fps: u32;
}

WINDOW_WIDTH 	:= 1920;
WINDOW_HEIGHT 	:= 1080;

// Not really constants but only 1 will ever exist
ZRENDERER 				: ZRenderer;
VMA_ALLOCATOR 			: VmaAllocator;
GLOBAL_DELETION_QUEUE 	: Deletion_Queue;

MOUSELOOK_SENSITIVITY	: float = 1;
CAMERA_MOVESPEED		: float = 0.1;

game_init :: (using state: *Game_State) -> bool {
	init_zworld(*world);
    init_archetype(*world, Archetype_Ship);
    register_observers(*world);

    // Renderer setup
    init_success, init_error := init_zrenderer(*ZRENDERER);
    if !init_success {
        print("ERROR: %\n", init_error);
        return false;
    }
    load_assets(*ZRENDERER);
    
    // Scene setup
    scene = create_zscene(VMA_ALLOCATOR, ZRENDERER.device, 
                          SCENE_MESHBUFFER_SIZE, SCENE_TRANSFORMBUFFER_SIZE);
    
    mesh_name := "ion_frigate";
    mesh, found := table_find(*ZRENDERER.mesh_map, mesh_name);
    if !found {
        print("WARNING: Could not find % mesh\n", mesh_name);
    }
    add_scene_mesh(*scene, mesh, Matrix4.{_11=-1, _22=-1, _33=1, _44=1});
    
    light : Point_Light;
    light.position = .{10,1,10};
    light.radius = 24;
    light.color = .{1,0,0,1};
    add_scene_point_light(*scene, light);
    add_scene_debug_sphere(*scene, Matrix4.{_11=-1, _22=-1, _33=1, _44=1});

	create_entity(*world, Archetype_Ship); // TODO: observer isn't triggering
    // Input setup
    SDL_SetRelativeMouseMode(SDL_TRUE);
    SDL_SetHint(SDL_HINT_MOUSE_RELATIVE_MODE_WARP, "1");
    
    // Timing
    frequency = SDL_GetPerformanceFrequency();
    last_counter = SDL_GetPerformanceCounter();
    
    return true;
}

game_handle_input :: (using state: *Game_State, event: *SDL_Event) {
	if event.type == {
		case SDL_QUIT;
			quit = true;
		case SDL_KEYUP;
			if event.key.keysym.sym == SDLK_ESCAPE quit = true;
		case SDL_WINDOWEVENT;
			if event.window.event == SDL_WINDOWEVENT_SIZE_CHANGED {
				ZRENDERER.framebuffer_resized = true;
			}
			else if event.window.event == SDL_WINDOWEVENT_MINIMIZED {
				ZRENDERER.minimized = true;
			}
			else if event.window.event == SDL_WINDOWEVENT_RESTORED {
				ZRENDERER.minimized = false;
			}
		case SDL_MOUSEMOTION;
			delta_x := cast,no_check(float) event.motion.xrel;
			delta_y := -cast,no_check(float) event.motion.yrel;

			sensitivity : float = cast,no_check(float)(MOUSELOOK_SENSITIVITY * delta_time);
			delta_yaw := make_rotor(.{0, 0, 1}, delta_x * sensitivity);
			delta_pitch := make_rotor(.{0, 1, 0}, -delta_y * sensitivity);

			ZRENDERER.camera.rotation = normalize(delta_yaw * ZRENDERER.camera.rotation * delta_pitch);
	}
}

game_update_camera :: (using state: *Game_State) {
    keyboard_state := SDL_GetKeyboardState(null);
    
    if keyboard_state[SDL_SCANCODE_W] {
        ZRENDERER.camera.translate(*ZRENDERER.camera, ZRENDERER.camera.forward * CAMERA_MOVESPEED);
    }
    else if keyboard_state[SDL_SCANCODE_S] {
        ZRENDERER.camera.translate(*ZRENDERER.camera, ZRENDERER.camera.forward * -CAMERA_MOVESPEED);
    }
    if keyboard_state[SDL_SCANCODE_D] {
        ZRENDERER.camera.translate(*ZRENDERER.camera, ZRENDERER.camera.right * CAMERA_MOVESPEED);
    }
    else if keyboard_state[SDL_SCANCODE_A] {
        ZRENDERER.camera.translate(*ZRENDERER.camera, ZRENDERER.camera.right * -CAMERA_MOVESPEED);
    }
}

game_tick :: (using state: *Game_State) {
	execute_Query_Position_Randomizer(*GAME_STATE.world, #code {
		
	});

	tick_world(*world, delta_time);
}

game_render :: (using state: *Game_State) {
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

game_shutdown :: (using state: *Game_State) {
    vkDeviceWaitIdle(ZRENDERER.device);
    deinit_zrenderer(*ZRENDERER);
    // Add world cleanup later
}

GAME_STATE : Game_State;

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
        
        // Process input
        while SDL_PollEvent(*event) {
            game_handle_input(*GAME_STATE, *event);
        }
        
        // Update camera from input
        game_update_camera(*GAME_STATE);
        
        // Game tick
        game_tick(*GAME_STATE);
        
        // Render
        game_render(*GAME_STATE);
    }
    
    game_shutdown(*GAME_STATE);
}