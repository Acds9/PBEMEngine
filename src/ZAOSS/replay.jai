Turn_File :: struct {
	game			: string;
	turn			: u32;
	start_step		: u32;
	end_step		: u32;
	step_resolution	: u32;

	timeline		: Turn_Timeline;
}

Replay_System :: struct {
	replay_world		: Game_World;

	active_turn_file	: Turn_File;
	current_step		: u32;
}

open_replay :: (game: string) {
	using *GAME_INSTANCE;
	replay_system.active_turn_file = .{};
	read_from_disk_turn(*replay_system.active_turn_file, game, 0);
	replay_system.replay_world.name = game;
	initialize_timeline(*current_orders, replay_system.active_turn_file.start_step, replay_system.active_turn_file.end_step);
	initialize_zworld(*replay_system.replay_world.world);
	initialize_zscene(*replay_system.replay_world.scene, VMA_ALLOCATOR, ZRENDERER.device);
	game_world_state = .REPLAY;
	menu_state = .NONE;
	// TODO: need to validate timeline here
	start_step := *replay_system.active_turn_file.timeline.steps[0];
	assert(!start_step.is_checkpoint, "ERROR: Malformed turn does not start on a checkpoint");
	checkpoint := *start_step.step_data.checkpoint;
	print("Num Entity Data: %\n", checkpoint.entity_data.count);
	for *checkpoint.entity_data {
		spawn_from_timeline_entity_data(it, *replay_system.replay_world.world);
	}
}