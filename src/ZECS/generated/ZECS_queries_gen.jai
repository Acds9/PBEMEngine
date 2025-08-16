
// Query Executor for Query_Position_Randomizer
execute_Query_Position_Randomizer :: (world: *ZWorld, $body: Code) #expand {
	MATCHING_ARCHETYPES		:: u16.[0];
	for arch_idx: MATCHING_ARCHETYPES {
		storage := *world.world_archetypes[arch_idx];
		if !storage.initialized continue;
		if storage.num_entities == 0 continue;

		`scale_array := array_view(Scale, *storage.entity_components[0], storage.num_entities);


		`generations := array_view_dynamic(storage.generations, storage.generations.count);
		`entity_count := storage.num_entities;
		`archetype_index  := arch_idx;
		`alive_mask  := *storage.alive_mask;
	
		#insert body;
	
	}
}
