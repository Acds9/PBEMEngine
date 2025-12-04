INPUT_COMMAND	:: enum u8 {
	MOVE_FORWARD;
	MOVE_BACKWARD;
	MOVE_RIGHT;
	MOVE_LEFT;
	MOVE_UP;
	MOVE_DOWN;

	MOUSE_BUTTON_LEFT;
	MOUSE_BUTTON_RIGHT;
	MOUSE_BUTTON_MIDDLE;

	TOGGLE_MOUSE_MODE;

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
	scancode		: u32;
	
	ctrl			: bool;
	alt				: bool;
}

Input_System	:: struct {
	mouse_position	: Vector2;
	mouse_delta		: Vector2;
	
	current_mode	: INPUT_MODE;

	commands			: [SDL_NUM_SCANCODES + 5]Command_State;

	mappings		: [INPUT_COMMAND.INPUT_COMMANDS_COUNT]Input_Binding;
}

load_default_mappings :: (using self: *Input_System) {
	mappings[INPUT_COMMAND.MOVE_FORWARD] = .{xx SDL_SCANCODE_W, false, false};
	mappings[INPUT_COMMAND.MOVE_BACKWARD] = .{xx SDL_SCANCODE_S, false, false};
	mappings[INPUT_COMMAND.MOVE_RIGHT] = .{xx SDL_SCANCODE_D, false, false};
	mappings[INPUT_COMMAND.MOVE_LEFT] = .{xx SDL_SCANCODE_A, false, false};
	mappings[INPUT_COMMAND.MOVE_UP] = .{xx SDL_SCANCODE_Q, false, false};
	mappings[INPUT_COMMAND.MOVE_DOWN] = .{xx SDL_SCANCODE_Z, false, false};

	mappings[INPUT_COMMAND.TOGGLE_MOUSE_MODE] = .{xx SDL_SCANCODE_TAB, false, false};

	mappings[INPUT_COMMAND.MOUSE_BUTTON_LEFT] = .{cast(u32) SDL_NUM_SCANCODES + cast(u32) SDL_BUTTON_LEFT, false, false};
	mappings[INPUT_COMMAND.MOUSE_BUTTON_RIGHT] = .{cast(u32) SDL_NUM_SCANCODES + cast(u32) SDL_BUTTON_MIDDLE, false, false};
	mappings[INPUT_COMMAND.MOUSE_BUTTON_MIDDLE] = .{cast(u32) SDL_NUM_SCANCODES + cast(u32) SDL_BUTTON_RIGHT, false, false};
}

input_pressed :: (using self: *Input_System, input: INPUT_COMMAND) {
	mapping := *mappings[input];
	command := *commands[mapping.scancode];

	command.key_down = true;
	command.held = true;
	command.held_time += xx,no_check GAME_STATE.delta_time;
}

input_relesed :: (using self: *Input_System, input: INPUT_COMMAND) {
	mapping := *mappings[input];
	command := *commands[mapping.scancode];

	command.key_down = false;
	command.held = false;
	command.held_time = 0;
}