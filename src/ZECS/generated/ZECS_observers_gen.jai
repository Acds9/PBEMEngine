
// Observer Executor for Observer_Ship_Spawn
execute_Observer_Ship_Spawn :: (game_state: *Game_State, entities: []ZEntity) {
	world := *game_state.world;
	archetype := entities[0].archetype;
	arch_storage := *world.world_archetypes[entities[0].archetype];
	for entity: entities {
		position := *get_entity_component(world, entity, Position);
		rotation := *get_entity_component(world, entity, Rotation);
		scale := *get_entity_component(world, entity, Scale);
		mesh_instance_address := *get_entity_component(world, entity, Mesh_Instance_Address);
		mesh_rep := *get_archetype_component(world, get_archetype(archetype), Mesh_Rep);
		Observer_Ship_Spawn_Event(entity, game_state);
	}
}

// Observer Registerer for Observer_Ship_Spawn
register_Observer_Ship_Spawn :: (world: *ZWorld) {
	MATCHING_ARCHETYPES		:: u16.[1];
	for arch_idx: MATCHING_ARCHETYPES {
		entry := Observer_Entry.{priority = 0, proc = execute_Observer_Ship_Spawn};
		for *world.observer_registry.on_created[arch_idx] {
			if it.proc == entry.proc {
				print("WARNING: Attempted to register an already registered observer: %\n", entry);
				return;
			}
		}
		array_add(*world.observer_registry.on_created[arch_idx], entry);
	}
}

// Observer Registration Function
register_observers :: (world: *ZWorld) {
	register_Observer_Ship_Spawn(world);
}
