Turn_File :: struct @serialize {
	game			: string;
	turn			: u32;
	start_step		: u32;
	end_step		: u32;
	step_resolution	: u32;

	timeline		: Turn_Timeline;
}  @serialize

Replay_System :: struct {
	active_turn_file	: Turn_File;
	order_file			: Order_File;
	current_step		: u32;

	autoplay			: bool;
	time				: float32;
	play_rate			: float32 = 1;

	start_time			: float32;
	end_time			: float32;

	replay_timeline		: Replay_Timeline;
	seconds_per_step	: float32;
}

set_replay_autoplay :: (is_autoplay: bool) {
	using *GAME_INSTANCE.replay_system;
	autoplay = is_autoplay;
}

set_replay_play_rate :: (rate: float32) {
	using *GAME_INSTANCE.replay_system;
	play_rate = rate;
}
// TODO: The damn collisions aren't working again, no BVH crash so probably the AABB not loading properly. 
set_replay_time :: (new_time: float32) {
	using *GAME_INSTANCE.replay_system;
	if new_time < start_time {
		time = 0;
		autoplay = false;
		update_replay_timeline(*GAME_INSTANCE.replay_system);
		return;
	}
	if new_time > end_time {
		time = end_time;
		autoplay = false;
		update_replay_timeline(*GAME_INSTANCE.replay_system);
		return;
	}
	time = new_time;
	current_step = xx,no_check floor(time * seconds_per_step);
	update_replay_timeline(*GAME_INSTANCE.replay_system);
}

increment_replay_time :: (dT: float32) {
	using *GAME_INSTANCE.replay_system;
	set_replay_time(time + dT*play_rate);
}

open_replay :: (game: string, turn: s32 = -1) {
	using *GAME_INSTANCE;
	replay_system.active_turn_file = .{};
	if turn < 0 {
		turn = 0; // TODO: needs to get latest turn here

	}
	read_from_disk_turn(*replay_system.active_turn_file, game, xx turn);
	ZRENDERER.debug_system.reset(*ZRENDERER.debug_system);
	destroy(*active_world); // TODO: need some handy way to switch between worlds and destroy the old one
	active_world = create_game_world(game, .REPLAY);
	menu_state = .NONE;

	replay_system.seconds_per_step = 1.0 / replay_system.active_turn_file.step_resolution;
	replay_system.start_time = replay_system.active_turn_file.start_step * replay_system.seconds_per_step;
	replay_system.end_time = replay_system.active_turn_file.end_step * replay_system.seconds_per_step;
	
	replay_system.order_file = .{replay_system.active_turn_file.game, replay_system.active_turn_file.turn, .{}};
	// TODO: need to validate timeline here
	replay_system.replay_timeline = generate_replay_timeline(*replay_system.active_turn_file.timeline);
	create_timeline_entities(*replay_system.active_turn_file.timeline, *active_world.world);

	ZRENDERER.imgui_system.show_timeline_controls = true;
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
		if GAME_INSTANCE.replay_system.autoplay {
			increment_replay_time(delta_time);
		}
	});
	barrier_wait(context.lane_barrier);
	scene_tick(game_world, delta_time);
	barrier_wait(context.lane_barrier);
	flush_observers(*game_world.world);
	barrier_wait(context.lane_barrier);
}

quit_replay :: () {
	vkDeviceWaitIdle(ZRENDERER.device); // 
	replay_system := *GAME_INSTANCE.replay_system;

	player_controller_clear_selection(*GAME_INSTANCE.player_controller);
	ZRENDERER.debug_system.reset(*ZRENDERER.debug_system);
	destroy(*GAME_INSTANCE.active_world);
	enter_main_menu();

	replay_system.order_file = .{}; // TODO: maybe should just reset/recreate the replay system when we enter/exit a replay?
	replay_system.current_step = 0;

	GAME_INSTANCE.menu_state = .MAIN;
	ZRENDERER.imgui_system.show_timeline_controls = false;
}
