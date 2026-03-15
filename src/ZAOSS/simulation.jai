ZLog :: #import "ZLog";

SNAPSHOT_FREQUENCY :: 10;

Simulation_Parameters :: struct {
	step_resolution		: u32;
	step_start			: u32;
	step_end			: u32;
	step_delta_time		: float32;
}

Simulation_State :: struct {
	current_step	: u32;
}

SIMULATION_STATE :: enum u8 {
	PENDING;
	SIMULATING;
	COMPLETED;
}

Simulation_Instance :: struct {
	state		: SIMULATION_STATE;
	game		: string;
	start_state_turn_file : Turn_File;
	parameters	: Simulation_Parameters;
	sim_state	: Simulation_State;
	game_world	: Game_World;
	record_system : Simulation_Record_System;
	order_timeline : Turn_Timeline; // This is the order-holding timeline that won't change, NOT the one replay is recorded to
	master_timeline : Turn_Timeline; // This is where the master timeline is recorded to that the server will use for the server's ground truth replay
}

Simulation_System :: struct {
	active_simulation : s32 = -1;
	simulations	: [..]Simulation_Instance;
}

queue_simulation :: (game: string, step_start: u32, step_end: u32, step_resolution: u32) {
	using *GAME_INSTANCE.simulation_system;
	array_add(*simulations, Simulation_Instance.{});
	entry := *simulations[simulations.count-1];
	entry.game = game;
	entry.parameters.step_resolution = step_resolution;
	entry.parameters.step_start = step_start;
	entry.parameters.step_end = step_end;
	entry.parameters.step_delta_time = 1.0 / step_resolution;

}

queue_simulation :: (game: string) {
	manifest : Manifest_File;
	read_manifest_name(game, *manifest);
	step_start := manifest.current_turn * manifest.default_turn_steps;
	step_end := step_start + manifest.default_turn_steps;
	queue_simulation(game, step_start, step_end, manifest.default_step_resolution);
}

simulate_pending_sims :: () {
	for *GAME_INSTANCE.simulation_system.simulations {
		if it.state == .PENDING {
			GAME_INSTANCE.simulation_system.active_simulation = xx it_index;
			simulate(it);
		}
	}
	narrow(#code{
		GAME_INSTANCE.simulation_system.active_simulation = -1;
		array_reset(*GAME_INSTANCE.simulation_system.simulations);
	});
}

get_active_simulation :: (using self: *Simulation_System) -> *Simulation_Instance, bool {
	if active_simulation < 0 {
		return null, false;
	}
	return *simulations[active_simulation], true;
}

simulate :: (sim_entry: *Simulation_Instance) {
	if sim_entry.state != .PENDING {
		print("WARNING: Attempted to simulate a non-pending request for game % whose current state is %, aborting.\n", sim_entry.game, sim_entry.state);
		return;
	}
	narrow(#code{
		ZLog.start_logging_session(*ZLog.ZLOGGER, sim_entry.game, 0);
		ZLog.write_to_log(*ZLog.ZLOGGER, .SIMULATION, .NONE, tprint("Initializing simulation for game %", sim_entry.game));
	});

	time_start := seconds_since_init();
	
	narrow(#code{
		// TODO: this needs to actually set up the scene from the game data, this is where we load in meshes, entities, whatever
		// Also needs multilane where possible
		sim_entry.game_world = create_game_world(tprint("sim_%", sim_entry.game), .SIMULATION);
		ZLog.write_to_log(*ZLog.ZLOGGER, .SIMULATION, .INITIALIZATION, "World initialization successful");

		initialize_timeline(*sim_entry.order_timeline, sim_entry.parameters.step_start, sim_entry.parameters.step_end);
		initialize_timeline(*sim_entry.master_timeline, sim_entry.parameters.step_start, sim_entry.parameters.step_end);
		ZLog.write_to_log(*ZLog.ZLOGGER, .SIMULATION, .INITIALIZATION, tprint("timeline initialized from step % to step %", sim_entry.parameters.step_start, sim_entry.parameters.step_end));
		order_files : [..]Order_File;
		read_from_disk_orders(*order_files, get_order_directory(sim_entry.game)); // TODO: it's because this isn't laned, this stuff needs to either be multithreaded or run on single
		load_orders_to_stream(*sim_entry.order_timeline.order_stream, *order_files);
		ZLog.write_to_log(*ZLog.ZLOGGER, .SIMULATION, .ORDER, tprint("Loaded % orders from disk to order stream", order_files.count));

		// Load previous state by spawning entities
		read_from_disk_turn(*sim_entry.start_state_turn_file, sim_entry.game, 0);
		create_start_state_from_timeline(*sim_entry.start_state_turn_file.timeline, *sim_entry.game_world.world);
		ZLog.write_to_log(*ZLog.ZLOGGER, .SIMULATION, .ORDER, "Start state created from timeline");
	});
	barrier_wait(context.lane_barrier);

	sim_entry.state = .SIMULATING;
	sim_entry.sim_state.current_step = sim_entry.parameters.step_start;
	diag_last_data_ptr : *u8;
	diag_last_snapshots_ptr : *Entity_Snapshot;
	while sim_entry.sim_state.current_step < sim_entry.parameters.step_end {
		simulation_tick(sim_entry);
		barrier_wait(context.lane_barrier);

		narrow(#code{
			simulation_record(sim_entry);
			flush_record_queue(*sim_entry.record_system, *sim_entry.game_world.world, sim_entry.sim_state.current_step, *sim_entry.master_timeline);
			diag_last_data_ptr = sim_entry.master_timeline.snapshot_stream.data.data;
			diag_last_snapshots_ptr = sim_entry.master_timeline.snapshot_stream.snapshots.data;
			ZLog.write_to_log(*ZLog.ZLOGGER, .SIMULATION, .ORDER, tprint("Step % simulated", sim_entry.sim_state.current_step));
			sim_entry.sim_state.current_step += 1;
		});
		barrier_wait(context.lane_barrier);
	}
	narrow(#code{
		time_end := seconds_since_init();
		print("Simulation Complete, time elapsed: %\n", time_end-time_start);

		// DIAG: Check if pointers changed between last sim step and post-sim
		current_data_ptr := sim_entry.master_timeline.snapshot_stream.data.data;
		current_snap_ptr := sim_entry.master_timeline.snapshot_stream.snapshots.data;
		if diag_last_data_ptr != current_data_ptr {
			print("!!! DATA PTR CHANGED: sim loop had %, post-sim has %\n", diag_last_data_ptr, current_data_ptr);
		} else {
			print("DIAG: data ptr unchanged: %\n", current_data_ptr);
		}
		if diag_last_snapshots_ptr != current_snap_ptr {
			print("!!! SNAPSHOTS PTR CHANGED: sim loop had %, post-sim has %\n", diag_last_snapshots_ptr, current_snap_ptr);
		}
		// DIAG: Check data content at offset 96 (first "bad" offset)
		if sim_entry.master_timeline.snapshot_stream.data.count > 108 {
			p96 := cast,no_check(*Position)(current_data_ptr + 96);
			print("DIAG data at offset 96: % (should be step 80 position)\n", p96.value);
			// Also check via last known pointer
			if diag_last_data_ptr != current_data_ptr {
				p96_old := cast,no_check(*Position)(diag_last_data_ptr + 96);
				print("DIAG data at offset 96 via OLD ptr: %\n", p96_old.value);
			}
		}

		print("POST-SIM data.data ptr: %, data.count: %, snapshots.count: %\n", sim_entry.master_timeline.snapshot_stream.data.data, sim_entry.master_timeline.snapshot_stream.data.count, sim_entry.master_timeline.snapshot_stream.snapshots.count);
		// DIAG: Also check start_state_turn_file to see if post-sim data matches it
		if sim_entry.start_state_turn_file.timeline.snapshot_stream.data.count >= 24 {
			stf_data := sim_entry.start_state_turn_file.timeline.snapshot_stream.data;
			stf_p0 := cast,no_check(*Position) stf_data.data;
			stf_p1 := cast,no_check(*Position) (stf_data.data + 12);
			print("DIAG START_STATE_TURN_FILE: data.data = %, count = %, data[0] = %, data[12] = %\n", stf_data.data, stf_data.count, stf_p0.value, stf_p1.value);
		}
		for sim_entry.master_timeline.snapshot_stream.snapshots {
			pos := cast,no_check(*Position) (sim_entry.master_timeline.snapshot_stream.data.data + it.data_offset);
			print("Step: %, Position: %, data_offset: %\n", it.step, pos.value, it.data_offset);
		}
		
		ZLog.write_to_log(*ZLog.ZLOGGER, .SIMULATION, .ORDER, tprint("Finished simulation of game: %, steps: %, time: % seconds\n", sim_entry.game, sim_entry.parameters.step_end-sim_entry.parameters.step_start, time_end-time_start));
		{
			start_turn : Turn_File;
			start_turn.game = sim_entry.game;
			start_turn.turn	= 0;
			start_turn.start_step = 0;
			start_turn.end_step = sim_entry.parameters.step_end;
			start_turn.step_resolution = sim_entry.parameters.step_resolution;
			start_turn.timeline = sim_entry.master_timeline;

			path := tprint("%/%", GAME_FOLDER_PATH, sim_entry.game);
			turn_path := tprint("%/%/%_0.%", path, TURN_FOLDER_NAME, sim_entry.game, TURN_EXT);
			file_delete(turn_path);
			turn_buffer : [..]u8;
			offset : s64;
			serialize(*turn_buffer, *start_turn);
			write_entire_file(turn_path, turn_buffer.data, turn_buffer.count);
		}
		ZLog.flush_log_buffers(*ZLog.ZLOGGER);
		destroy(*sim_entry.game_world);
	});
}

// TODO: lots of barriers here, are they all needed?
simulation_tick :: (using sim_instance: *Simulation_Instance) {
	dT := parameters.step_delta_time;
	simulation_timeline_tick(*order_timeline, sim_state.current_step, *game_world.world);
	barrier_wait(context.lane_barrier);
	scene_tick(*game_world, dT);
	barrier_wait(context.lane_barrier);
	
	execute_Query_Update_Physics(*game_world.world, #code {
		local_thrust := rotate(.{1,0,0}, rotation.value) * thrust.value*dT;
		linear_velocity.value =  linear_velocity.value + local_thrust;
		linear_velocity.value *= exp(-1 * dT);
		position.value += linear_velocity.value*dT;
		rotation.value = add_angular_delta(rotation.value, rotational_velocity.value, dT);
	});

	barrier_wait(context.lane_barrier);
	flush_observers(*game_world.world);
}

simulation_timeline_tick :: (timeline: *Turn_Timeline, step: u32, world: *ZWorld) {
	orders := read_stream(*timeline.order_stream, step);
	for *orders {
		execute_order(world, it, timeline.order_stream.data);
	}
}

simulation_record :: (using sim_instance: *Simulation_Instance) {
	if !(sim_instance.sim_state.current_step % SNAPSHOT_FREQUENCY) {
		for entity: game_world.world.world_entities {
			record_snapshot(*record_system, entity, Position);
		}
	}
}