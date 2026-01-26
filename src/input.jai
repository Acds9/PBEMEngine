INPUT_COMMAND	:: enum u8 {
	NONE;
	MOVE_FORWARD;
	MOVE_BACKWARD;
	MOVE_RIGHT;
	MOVE_LEFT;
	MOVE_UP;
	MOVE_DOWN;

	MOUSE_BUTTON_LEFT; // These are wrong, these are commands not buttons, e.g. "Fire Main" not this
	MOUSE_BUTTON_RIGHT;
	MOUSE_BUTTON_MIDDLE;

	TOGGLE_MOUSE_MODE;

	TOGGLE_IMGUI_DEBUG_METRICS;
	TOGGLE_IMGUI_DEBUG_RENDERING;
	
	INPUT_COMMANDS_COUNT; 
}

INPUT_MODE :: enum u8 {
	CAMERA_MODE;
	MOUSE_MODE;
}

Command_State	:: struct {
	key_down	: bool;
	key_up		: bool;

	held		: bool;

	held_time	: float;
}

Input_Binding	:: struct {
	command			: INPUT_COMMAND;
	
	ctrl			: bool;
	alt				: bool;
}
// TODO: should somehow merge this and player controller?
Input_System	:: struct {
	mouse_position	: Vector2;
	mouse_delta		: Vector2;
	
	current_mode	: INPUT_MODE;

	commands		: [INPUT_COMMAND.INPUT_COMMANDS_COUNT]Command_State;
	
	mappings		: [SDL_NUM_SCANCODES + 5]Input_Binding;
}

initialize_input_system :: (using self: *Input_System) {
	load_default_mappings(self);
}

load_default_mappings :: (using self: *Input_System) {
	mappings[SDL_SCANCODE_W] = .{xx INPUT_COMMAND.MOVE_FORWARD, false, false};
	mappings[SDL_SCANCODE_S] = .{xx INPUT_COMMAND.MOVE_BACKWARD, false, false};
	mappings[SDL_SCANCODE_D] = .{xx INPUT_COMMAND.MOVE_RIGHT, false, false};
	mappings[SDL_SCANCODE_A] = .{xx INPUT_COMMAND.MOVE_LEFT, false, false};
	mappings[SDL_SCANCODE_Q] = .{xx INPUT_COMMAND.MOVE_UP, false, false};
	mappings[SDL_SCANCODE_Z] = .{xx INPUT_COMMAND.MOVE_DOWN, false, false};

	mappings[SDL_SCANCODE_TAB] = .{xx INPUT_COMMAND.TOGGLE_MOUSE_MODE, false, false};

	mappings[SDL_SCANCODE_F1] = .{xx INPUT_COMMAND.TOGGLE_IMGUI_DEBUG_METRICS, false, false};
	mappings[SDL_SCANCODE_F2] = .{xx INPUT_COMMAND.TOGGLE_IMGUI_DEBUG_RENDERING, false, false};

	mappings[SDL_NUM_SCANCODES + SDL_BUTTON_LEFT] 	= .{INPUT_COMMAND.MOUSE_BUTTON_LEFT, false, false};
	mappings[SDL_NUM_SCANCODES + SDL_BUTTON_MIDDLE] = .{INPUT_COMMAND.MOUSE_BUTTON_MIDDLE, false, false};
	mappings[SDL_NUM_SCANCODES + SDL_BUTTON_RIGHT] 	= .{INPUT_COMMAND.MOUSE_BUTTON_RIGHT, false, false};
}

input_handle_sdl_event :: (using self: *Input_System, event: *SDL_Event) {
    if event.type == {
        case SDL_KEYDOWN;
            if !event.key.repeat {  // Ignore key repeat
                input_pressed(self, cast,no_check(u32)event.key.keysym.scancode);
            }
        case SDL_KEYUP;
            input_released(self, cast,no_check(u32)event.key.keysym.scancode);
            
        case SDL_MOUSEBUTTONDOWN;
            input_pressed(self, cast,no_check(u32)SDL_NUM_SCANCODES + cast,no_check(u32)event.button.button);
        case SDL_MOUSEBUTTONUP;
            input_released(self, cast,no_check(u32)SDL_NUM_SCANCODES + cast,no_check(u32)event.button.button);
            
        case SDL_MOUSEMOTION;
            mouse_delta.x += cast,no_check(float)event.motion.xrel;
            mouse_delta.y -= cast,no_check(float)event.motion.yrel;
            mouse_position.x = cast,no_check(float)event.motion.x;
            mouse_position.y = cast,no_check(float)event.motion.y;
    }
}

get_command :: (using self: *Input_System, input: INPUT_COMMAND) -> *Command_State {
	return *commands[input];
}

get_command :: (using self: *Input_System, input: u32) -> *Command_State {
	return *commands[mappings[input].command];
}

input_pressed :: (using self: *Input_System, input: u32) {
	command := get_command(self, input);
	command.held = true;
	command.key_down = true;
}

input_released :: (using self: *Input_System, input: u32) {
	command := get_command(self, input);
	command.held = false;
	command.key_up = true;
}

input_begin_frame :: (using self: *Input_System) {
	mouse_delta = .{};
	for *command: commands {
		command.key_down = false;
		command.key_up = false;
	}
}

tick_input_commands :: (using self: *Input_System, delta_time: float) {
	for *command: commands {
		if command.held {
			command.key_down = command.held_time == 0;
			command.held_time += delta_time;
		}
		else {
			command.key_up = command.held_time > 0;
			command.held_time = 0;
		}
	}
}

toggle_mouse_input_mode :: (using self: *Input_System) {
	if current_mode == .CAMERA_MODE {
        current_mode = .MOUSE_MODE;
        SDL_SetRelativeMouseMode(SDL_FALSE);
    } else {
        current_mode = .CAMERA_MODE;
        SDL_SetRelativeMouseMode(SDL_TRUE);
    }
}