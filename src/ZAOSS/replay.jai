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
	initialize_zworld(*replay_system.replay_world.world, .REPLAY);
	initialize_zscene(*replay_system.replay_world.scene, VMA_ALLOCATOR, ZRENDERER.device);
	game_world_state = .REPLAY;
	menu_state = .NONE;
	replay_system.order_file = .{replay_system.active_turn_file.game, replay_system.active_turn_file.turn, .{}};
	// TODO: need to validate timeline here
	create_start_state_from_timeline(*replay_system.active_turn_file.timeline, *replay_system.replay_world.world);
}

tick_replay :: (using game_world: *Game_World, delta_time: float32) {
	execute_Query_Update_Render_Proxy(*world, #code { 
		transform := Transform.{position.value, rotation.value, scale.value};
		matrix := transform_to_matrix4(transform);
		idx := mesh_render_proxy_ec.value;
				
		mesh_instance := render_get_mesh_instance(*scene, idx);
		render_set_transform(*game_world.scene, idx, *matrix);
	});
	narrow(#code{
		debug_tick();
	});
	barrier_wait(context.lane_barrier);
	scene_tick(game_world, delta_time);
	barrier_wait(context.lane_barrier);
	flush_observers(*game_world.world);
	barrier_wait(context.lane_barrier);
}