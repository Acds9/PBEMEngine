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
	order_timeline : Turn_Timeline; // This is the order-holding timeline that won't change, NOT the one replay is recorded to
}

Simulation_System :: struct {
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
			simulate(it);
		}
	}
}

get_simulation_entry :: (game: string) -> *Simulation_Instance {
	for *GAME_INSTANCE.simulation_system.simulations {
		if it.game == game {
			return it;
		}
	}
	return null;
}

simulate :: (sim_entry: *Simulation_Instance) {
	if sim_entry.state != .PENDING {
		print("WARNING: Attempted to simulate a non-pending request for game % whose current state is %, aborting.", sim_entry.game, sim_entry.state);
		return;
	}
	
	time_start := seconds_since_init();
	sim_entry.game_world.name = sim_entry.game;
	narrow(#code{
		// TODO: this needs to actually set up the scene from the game data, this is where we load in meshes, entities, whatever
		// Also needs multilane where possible
		initialize_zscene(*sim_entry.game_world.scene, VMA_ALLOCATOR, ZRENDERER.device);
		initialize_zworld(*sim_entry.game_world.world);

		initialize_timeline(*sim_entry.order_timeline, sim_entry.parameters.step_start, sim_entry.parameters.step_end);
		order_files : [..]Order_File;
		print("CALLED\n");
		read_from_disk_orders(*order_files, get_order_directory(sim_entry.game)); // TODO: it's because this isn't laned, this stuff needs to either be multithreaded or run on single
		load_orders_to_stream(*sim_entry.order_timeline.order_stream, *order_files);

		// Load previous state by spawning entities
		read_from_disk_turn(*sim_entry.start_state_turn_file, sim_entry.game, 0);
		create_start_state_from_timeline(*sim_entry.start_state_turn_file.timeline, *sim_entry.game_world.world);
	});
	barrier_wait(context.lane_barrier);

	context.headless = true;
	sim_entry.state = .SIMULATING;
	sim_entry.sim_state.current_step = sim_entry.parameters.step_start;
	while sim_entry.sim_state.current_step < sim_entry.parameters.step_end {
		simulation_timeline_tick(*sim_entry.order_timeline, sim_entry.sim_state.current_step, *sim_entry.game_world.world); 
		barrier_wait(context.lane_barrier);
		scene_tick(*sim_entry.game_world, sim_entry.parameters.step_delta_time);
		barrier_wait(context.lane_barrier);
        game_tick(*sim_entry.game_world, sim_entry.parameters.step_delta_time);
		barrier_wait(context.lane_barrier);
		// TODO: lots of barriers here, are they all needed?
		sim_entry.sim_state.current_step += 1;
		// TODO: need to start serializing stuff that happens in the game, need orders first?
	}
	context.headless = false;
	narrow(#code{
		time_end := seconds_since_init();
		print("Finished simulation of game: %, steps: %, time: % seconds\n", sim_entry.game, sim_entry.parameters.step_end-sim_entry.parameters.step_start, time_end-time_start);
		{
			start_turn : Turn_File;
			start_turn.game = sim_entry.game;
			start_turn.turn	= 0;
			start_turn.start_step = 0;
			start_turn.end_step = sim_entry.parameters.step_end;
			start_turn.step_resolution = sim_entry.parameters.step_resolution;

			initialize_timeline(*start_turn.timeline, sim_entry.parameters.step_start,sim_entry.parameters.step_end);
			create_timeline_checkpoint(*start_turn.timeline.snapshot_stream, *sim_entry.game_world.world, 0);

			pos := get_entity_component(*sim_entry.game_world.world, .{0,0,1}, Position);
			print("Entity % Position value is: %\n",  ZEntity.{0,0,1}, pos.value);

			path := tprint("%/%", GAME_FOLDER_PATH, sim_entry.game);
			turn_path := tprint("%/%/%_0.%", path, TURN_FOLDER_NAME, sim_entry.game, TURN_EXT);
			file_delete(turn_path);
			turn_buffer : [..]u8;
			offset : s64;
			serialize(*turn_buffer, *start_turn);
			write_entire_file(turn_path, turn_buffer.data, turn_buffer.count);
		}
	});
	
}

simulation_timeline_tick :: (timeline: *Turn_Timeline, step: u32, world: *ZWorld) {
	orders := read_stream(*timeline.order_stream, step);
	for *orders {
		execute_order(world, it, timeline.order_stream.data);
	}
}