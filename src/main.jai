#import "Basic";
#import "Random";
#import "Math";
#import "GL";
#import "SDL";
#import "Input";


WINDOW_WIDTH 	:= 1920;
WINDOW_HEIGHT 	:= 1080;

z_renderer : ZRenderer;

main :: () {
	world := create_zworld();

	init_archetype(world, Archetype_Ship); // Manual for now
	
	register_Observer_Ship_Spawn(world);
	
	create_entity_batch(world, Archetype_Ship, 16);
    
	init_success, init_error := init_zrenderer(*z_renderer);
	if !init_success {
		print("ERROR: %\n", init_error); 
		return;
	}
	
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
                        z_renderer.framebuffer_resized = true;
                    }
					else if event.window.event == SDL_WINDOWEVENT_MINIMIZED {
						z_renderer.minimized = true;
					}
					else if event.window.event == SDL_WINDOWEVENT_RESTORED  {
						z_renderer.minimized = false;
					}
            }
        }		
		if !z_renderer.minimized {
			draw_frame(*z_renderer);
		}
		else 
		{
			sleep_milliseconds(50);
		}

		vkDeviceWaitIdle(z_renderer.logical_device);
    }

	deinit_zrenderer(*z_renderer);
}

