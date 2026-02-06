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
	game_world	: Game_World;
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
		initialize_zscene(*sim_entry.game_world.scene, VMA_ALLOCATOR, ZRENDERER.device);
		initialize_zworld(*sim_entry.game_world.world);
	}
	barrier_wait(context.lane_barrier);

	timeline : Turn_Timeline;
	initialize_timeline(*timeline, sim_entry.parameters.step_start, sim_entry.parameters.step_end);
	load_orders_to_timeline(sim_entry.game, *timeline);

	context.headless = true;
	sim_entry.state = .SIMULATING;
	sim_entry.sim_state.current_step = sim_entry.parameters.step_start;
	while sim_entry.sim_state.current_step < sim_entry.parameters.step_end {
		scene_tick(*sim_entry.game_world, sim_entry.parameters.step_delta_time);
		barrier_wait(context.lane_barrier);
        game_tick(*sim_entry.game_world, sim_entry.parameters.step_delta_time);
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

Snapshot :: struct {
	step			: u32;
	entity_count 	: u32;
	data_size		: u32;
	entity_data		: [..]u8; // in format {ZEntity, component_data}
}

serialize_snapshot :: (dest: *[..]u8, src: *Snapshot) {
	serialize_to_buffer(dest, *src.step);
	serialize_to_buffer(dest, *src.entity_count);
	serialize_to_buffer(dest, *src.data_size);
	serialize_to_buffer(dest, *src.entity_data.data);
}

deserialize_snapshot :: (dest: *Snapshot, src: []u8, offset: *s64) {
	deserialize_from_buffer(*dest.step, src, offset);
	deserialize_from_buffer(*dest.entity_count, src, offset);
	deserialize_from_buffer(*dest.data_size, src, offset);
	deserialize_from_buffer(*dest.entity_data, src, offset, dest.data_size);
}

serialize_entity :: (dest: *[..]u8, world: *ZWorld, entity: ZEntity) {
	archetype : *Archetype_Storage = *world.world_archetypes[entity.archetype];
	// TODO: autogenerate this NOTE: do we even gain anything from autogenerating it?
	serialize_to_buffer(dest, *entity.index);
	serialize_to_buffer(dest, *entity.archetype);
	serialize_to_buffer(dest, *entity.gen);
	// Don't need component count, archetypes are the same across client and server
	for *archetype.entity_components {
		serialize_to_buffer(dest, *it[entity.index].data, it.stride);
	}
}

deserialize_entity :: (world: *ZWorld, src: []u8, offset: *s64) {
	entity : ZEntity;
	deserialize_from_buffer(*entity.index, src, offset); 
	deserialize_from_buffer(*entity.archetype, src, offset); 
	deserialize_from_buffer(*entity.gen, src, offset); 

	create_entity(world, get_archetype(entity.archetype), entity.index, entity.gen);

	archetype_data : *Archetype_Data = *ARCHETYPE_DATABASE[entity.archetype];
	for archetype_data.entity_components {
		component_storage : *Entity_Component_Storage = get_EC_storage_ptr(world, get_archetype(entity.archetype), it);
		component_ptr := component_storage.data.data + entity.index * component_storage.stride;
		deserialize_from_buffer(component_ptr, src, offset, component_storage.stride);
	}
}

take_snapshot :: (dest: *Snapshot, step: u32, world: *ZWorld) {
	dest.step = step;
	dest.entity_count = xx world.world_entities.count;
	for world.world_entities {
		serialize_entity(*dest.entity_data, world, it);
	}
	dest.data_size = xx dest.entity_data.count;
}

snapshot_simulation :: (dest: *Snapshot, simulation: *Simulation_Instance) {
	world := *simulation.game_world.world;
	take_snapshot(dest, simulation.sim_state.current_step, world);
} 

