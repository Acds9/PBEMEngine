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
	
    // Renderer setup
    init_success, init_error := init_zrenderer(*ZRENDERER);
    if !init_success {
        print("ERROR: %\n", init_error);
        return false;
    }
    load_assets(*ZRENDERER);
    
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
	position_2.pos = .{1,1,10};
	light_component_2 := get_entity_component(*world, light_entity_2, Point_Light_Component);
    light_component_2.radius = 64;
    light_component_2.color = .{.3,1,.3,1};
	
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

current_position : Vector3;
game_tick :: (using state: *Game_State) {
	ZRENDERER.debug_system.reset(*ZRENDERER.debug_system);
	{
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
	}
	{
		execute_Query_Update_Render_Proxy(*GAME_STATE.world, #code {
			for *pos: position_array {
				rot := rotation_array[it_index];
				scale := scale_array[it_index];
				transform := Transform.{pos.pos, rot.rot, scale.scale};
				matrix := transform_to_matrix4(transform);
				address := mesh_render_proxy_ec_array[it_index].mesh_address;
				if address {
					mesh_instance := render_get_mesh_instance(*GAME_STATE.scene, address);
					render_set_transform(*GAME_STATE.scene, mesh_instance, *matrix);
				}
				
			}
		});
	}
	{
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