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

	z_scene = init_zscene(VMA_ALLOCATOR, ZRENDERER.device, SCENE_MESHBUFFER_SIZE, SCENE_TRANSFORMBUFFER_SIZE);
	
	event : SDL_Event;
	quit := false;
    while !quit {
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
            }
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

