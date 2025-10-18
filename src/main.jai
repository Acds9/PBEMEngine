#import "Basic";
#import "Random";
#import "Math";
#import "GL";
#import "SDL";
#import "Input";


WINDOW_WIDTH 	:= 1920;
WINDOW_HEIGHT 	:= 1080;

// Not really constants but only 1 will ever exist
ZRENDERER 				: ZRenderer;
VMA_ALLOCATOR 			: VmaAllocator;
GLOBAL_DELETION_QUEUE 	: Deletion_Queue;

ZRENDERER_DELTATIME		: float64;
ZRENDERER_FRAMESPERSECOND : u32;

MOUSELOOK_SENSITIVITY	: float = 1;
CAMERA_MOVESPEED		: float = 0.1;

z_scene		: ZScene; // This will later not be constant, so we don't make it a pseudo-constant

main :: () {
	world := create_zworld();

	init_archetype(world, Archetype_Ship); // Manual for now
	
	register_Observer_Ship_Spawn(world);
	
	create_entity_batch(world, Archetype_Ship, 16);
    
	init_success, init_error := init_zrenderer(*ZRENDERER);
	if !init_success {
		print("ERROR: %\n", init_error); 
		return;
	}

	load_assets(*ZRENDERER);

	z_scene = create_zscene(VMA_ALLOCATOR, ZRENDERER.device, SCENE_MESHBUFFER_SIZE, SCENE_TRANSFORMBUFFER_SIZE);
	
	mesh_name := "ion_frigate";
	mesh, found := table_find(*ZRENDERER.mesh_map, mesh_name);
	if !found {
		print("WARNING: Could not find % mesh\n", mesh_name);
	}
	add_scene_mesh(*z_scene, mesh, Matrix4.{_11=-1, _22=-1, _33=1, _44=1});

	light : Point_Light; 
	light.position 	= .{10,1,10};
	light.radius	= 24;
	light.color		= .{1,0,0,1};

	add_scene_point_light(*z_scene, light);


	SDL_SetRelativeMouseMode(SDL_TRUE);
	SDL_SetHint(SDL_HINT_MOUSE_RELATIVE_MODE_WARP, "1"); 

	// Deltatime and performance
	frequency 		: u64 = SDL_GetPerformanceFrequency();
	last_counter	: u64 = SDL_GetPerformanceCounter();

	event : SDL_Event;
	quit := false;
    while !quit {

		// deltatime and fps
		current_counter : u64 = SDL_GetPerformanceCounter();
		ZRENDERER_DELTATIME = cast,no_check(float64)(current_counter - last_counter)/cast,no_check(float64)frequency;
		ZRENDERER_FRAMESPERSECOND = cast,no_check(u32)(1/ZRENDERER_DELTATIME);
		last_counter = current_counter;

        while SDL_PollEvent(*event) {
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
					else if event.window.event == SDL_WINDOWEVENT_RESTORED  {
						ZRENDERER.minimized = false;
					}
				case SDL_MOUSEMOTION;
					   	delta_x := cast,no_check(float) event.motion.xrel;
						delta_y := -cast,no_check(float) event.motion.yrel;
    
						sensitivity : float = cast,no_check(float)(MOUSELOOK_SENSITIVITY * ZRENDERER_DELTATIME);

						delta_yaw   := make_rotor(.{0, 0, 1}, delta_x * sensitivity);
    					delta_pitch := make_rotor(.{0, 1, 0}, -delta_y * sensitivity);
    
						// Apply to camera rotor
						ZRENDERER.camera.rotation = normalize(delta_yaw * ZRENDERER.camera.rotation * delta_pitch);

            }
        }		

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
		
		if keyboard_state[SDL_SCANCODE_SPACE] {
			// Space is held
		}
		if !ZRENDERER.minimized {
			draw_frame(*ZRENDERER, *z_scene);
		}
		else 
		{
			sleep_milliseconds(50);
		}
		if ZRENDERER.resize_requested {
			resize_swapchain(*ZRENDERER);
		}

		vkDeviceWaitIdle(ZRENDERER.device);
    }

	deinit_zrenderer(*ZRENDERER);
}

