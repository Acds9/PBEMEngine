
// Observer Executor for Observer_Ship_Spawn
execute_Observer_Ship_Spawn :: (world: *ZWorld, arch_idx: u16, entities: []ZEntity) {
	arch_storage := *world.world_archetypes[arch_idx];
	for entity: entities {
		position := *get_entity_component(world, entity, Position);
		rotation := *get_entity_component(world, entity, Rotation);
		scale := *get_entity_component(world, entity, Scale);
		mesh_instance_address := *get_entity_component(world, entity, Mesh_Instance_Address);
		mesh_rep := *get_archetype_component(world, arch_idx, Mesh_Rep);
		Observer_Ship_Spawn.PROC(entity, arch_idx, world);
	}
}

// Observer Registerer for Observer_Ship_Spawn
register_Observer_Ship_Spawn :: (world: *ZWorld) {
	MATCHING_ARCHETYPES		:: u16.[0];
	for arch_idx: MATCHING_ARCHETYPES {
		entry := Observer_Entry.{priority = 0, proc = execute_Observer_Ship_Spawn};
		array_add(*world.observer_registry.on_created[arch_idx], entry);
	}
}
