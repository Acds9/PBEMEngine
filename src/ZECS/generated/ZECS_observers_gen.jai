
// Observer Executor for Observer_Ship_Spawn
execute_Observer_Ship_Spawn :: (world: *ZWorld, arch_idx: u16, entities: []ZEntity) {
	arch_storage := *world.world_archetypes[arch_idx];
}

// Observer Registerer for Observer_Ship_Spawn
register_Observer_Ship_Spawn :: (world: *ZWorld) {
	MATCHING_ARCHETYPES		:: u16.[0];
	for arch_idx: MATCHING_ARCHETYPES {
		entry := Observer_Entry.{priority = 0, proc = execute_Observer_Ship_Spawn};
		array_add(*world.observer_registry.on_created[arch_idx], entry);
	}
}
