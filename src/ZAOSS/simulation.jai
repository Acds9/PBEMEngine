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
	parameters	: Simulation_Parameters;
	sim_state	: Simulation_State;
	scene		: ZScene;
	world		: ZWorld;
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
	manifest : Game_Manifest;
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

	if context.thread_index == 0 {
		// TODO: this needs to actually set up the scene from the game data, this is where we load in meshes, entities, whatever
		sim_entry.scene = create_zscene(VMA_ALLOCATOR, ZRENDERER.device); // TODO: either this returns a ZScene or it follows the ZWorld method of passing a pointer, pick one
		init_zworld(*sim_entry.world);
	}
	barrier_wait(context.lane_barrier);
	
	context.headless = true;
	sim_entry.state = .SIMULATING;
	sim_entry.sim_state.current_step = sim_entry.parameters.step_start;
	while sim_entry.sim_state.current_step < sim_entry.parameters.step_end {
		scene_tick(*sim_entry.scene);
		barrier_wait(context.lane_barrier);
        game_tick();
		barrier_wait(context.lane_barrier);

		sim_entry.sim_state.current_step += 1;
		// TODO: need to start serializing stuff that happens in the game, need orders first?
	}
	context.headless = false;
	if context.thread_index == 0 {
		time_end := seconds_since_init();
		print("Finished simulation of game: %, time: % seconds\n", sim_entry.game, time_end-time_start);
	}
	
}