Turn_File :: struct {
	game			: string;
	turn			: u32;
	start_step		: u32;
	end_step		: u32;
	step_resolution	: u32;

	timeline		: Turn_Timeline;
}  @serialize

Replay_System :: struct {
	replay_world		: Game_World;

	active_turn_file	: Turn_File;
	order_file			: Order_File;
	current_step		: u32;
}

open_replay :: (game: string, turn: s32 = -1) {
	using *GAME_INSTANCE;
	replay_system.active_turn_file = .{};
	if turn < 0 {
		turn = 0; // TODO: needs to get latest turn here

	}
	read_from_disk_turn(*replay_system.active_turn_file, game, xx turn);
	replay_system.replay_world.name = game;
	initialize_zworld(*replay_system.replay_world.world);
	initialize_zscene(*replay_system.replay_world.scene, VMA_ALLOCATOR, ZRENDERER.device);
	game_world_state = .REPLAY;
	menu_state = .NONE;
	replay_system.order_file = .{replay_system.active_turn_file.game, replay_system.active_turn_file.turn, .{}};
	// TODO: need to validate timeline here
	create_start_state_from_timeline(*replay_system.active_turn_file.timeline, *replay_system.replay_world.world);
}