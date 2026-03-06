Turn_File :: struct {
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
}

set_replay_autoplay :: (is_autoplay: bool) {
	using *GAME_INSTANCE.replay_system;
	autoplay = is_autoplay;
}

set_replay_play_rate :: (rate: float32) { // TODO: this won't work, just multiplying deltatime will skip steps
	using *GAME_INSTANCE.replay_system;
	play_rate = rate;
}

set_replay_time :: (new_time: float32) {
	using *GAME_INSTANCE.replay_system;
	if new_time < 0 {
		time = 0;
		autoplay = false;
		return;
	}
	per_step_time := 1/cast,no_check(float32)active_turn_file.step_resolution;
	max_time : float32 = xx,no_check (active_turn_file.end_step * per_step_time);
	if new_time > max_time {
		time = max_time;
		autoplay = false;
		return;
	}
	time = new_time;
	new_step : u32 = xx,no_check floor(time * cast,no_check(float32)active_turn_file.step_resolution);
	set_replay_step(new_step);
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

	replay_system.order_file = .{replay_system.active_turn_file.game, replay_system.active_turn_file.turn, .{}};
	// TODO: need to validate timeline here
	create_start_state_from_timeline(*replay_system.active_turn_file.timeline, *active_world.world);

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

set_replay_step :: (step: u32) {
	using *GAME_INSTANCE.replay_system;

	if step < xx,no_check active_turn_file.start_step {
		current_step = active_turn_file.start_step;
	} else if step > xx,no_check active_turn_file.end_step {
		current_step = active_turn_file.end_step;
	} else {
		current_step = xx,no_check step;	
	}

	process_replay_step(current_step);
} 

increment_replay_step :: (count: s32) {
	using *GAME_INSTANCE.replay_system;
	new_step : s32 = xx,no_check current_step + count;
	set_replay_step(xx,no_check clamp(new_step, xx,no_check active_turn_file.start_step, xx,no_check active_turn_file.end_step));
}

reprocess_replay_to_step :: (start_step: u32, target_step: u32) {
	using *GAME_INSTANCE.replay_system;
	for start_step..target_step {
		process_replay_step(it);
	}
	current_step = target_step;
}

process_replay_step :: (step: u32) {
	using *GAME_INSTANCE.replay_system;
	turn_timeline := *active_turn_file.timeline;
	snapshots := read_stream(*turn_timeline.snapshot_stream, step);
	for snapshots {
		slice := subslice(turn_timeline.snapshot_stream.data, it.data_offset, it.data_size);
		offset : s64;
		deserialize_entity_component_data(it.entity, *GAME_INSTANCE.active_world.world, slice, it.intel_level, *offset);
	}
}

