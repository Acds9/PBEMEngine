#import "Basic";
#import "Random";
#import "Math";
#import "GL";
#import "SDL";
#import "Input";

WINDOW_WIDTH 	:= 1920;
WINDOW_HEIGHT 	:= 1080;

main :: () {
	world := create_zworld();

	init_archetype(world, Archetype_Ship); // Manual for now
	
	register_Observer_Ship_Spawn(world);
	
	create_entity_batch(world, Archetype_Ship, 16);

	window := SDL_CreateWindow("Z-Engine", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, xx WINDOW_WIDTH, xx WINDOW_HEIGHT, SDL_WINDOW_OPENGL|SDL_WINDOW_RESIZABLE);
	
	// Check that the window was successfully created
    if window == null {
        // In the case that the window could not be made...
        print("Could not create window: %\n", to_string(SDL_GetError()));
        return;
    }

    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, xx SDL_GL_CONTEXT_PROFILE_CORE);

    gl_context := SDL_GL_CreateContext(window);
    if !gl_context {
        print( "Could not create OpenGL context: %\n", to_string(SDL_GetError()));
        return;
    }  
	gl_load(*gl, SDL_GL_GetProcAddress);

	print ("GL Vendor = %\n", to_string(glGetString(GL_VENDOR)));
    print ("GL Version = %\n", to_string(glGetString(GL_VERSION)));

	init_success, init_error := init_rendering();
	if !init_success {
		print("ERROR: %\n", init_error); 
		return;
	}
	
	quit := false;
    while !quit {
		event : SDL_Event;
        while SDL_PollEvent(*event) {
            if event.type == {
                case SDL_QUIT;
                    quit = true;
                case SDL_KEYUP;
                    if event.key.keysym.sym == SDLK_ESCAPE quit = true;
                case SDL_WINDOWEVENT;
                    if event.window.event == SDL_WINDOWEVENT_SIZE_CHANGED {
                        WINDOW_WIDTH = event.window.data1;
                        WINDOW_HEIGHT = event.window.data2;
                    }
            }
        }		
		draw_frame(window);
    }

	deinit_rendering();

    SDL_DestroyWindow(window);
    SDL_Quit();
}

