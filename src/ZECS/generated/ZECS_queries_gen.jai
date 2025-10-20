
// Query Executor for Query_Position_Randomizer
execute_Query_Position_Randomizer :: (world: *ZWorld, $body: Code) #expand {
	storage := *world.world_archetypes[0];
	{
		if storage.initialized && storage.num_entities != 0 {

			`scale_array := array_view(Scale, *storage.entity_components[2], storage.num_entities);


			`generations := array_view_dynamic(storage.generations, storage.generations.count);
			`entity_count := storage.num_entities;
			`archetype_index  := 0;
			`alive_mask  := *storage.alive_mask;

			#insert body;
		}
	}

	storage := *world.world_archetypes[1];
	{
		if storage.initialized && storage.num_entities != 0 {

			`scale_array := array_view(Scale, *storage.entity_components[2], storage.num_entities);


			`generations := array_view_dynamic(storage.generations, storage.generations.count);
			`entity_count := storage.num_entities;
			`archetype_index  := 1;
			`alive_mask  := *storage.alive_mask;

			#insert body;
		}
	}

}

// Query Executor for Query_Update_Render_Proxy
execute_Query_Update_Render_Proxy :: (world: *ZWorld, $body: Code) #expand {
	storage := *world.world_archetypes[0];
	{
		if storage.initialized && storage.num_entities != 0 {

			`position_array := array_view(Position, *storage.entity_components[0], storage.num_entities);
			`rotation_array := array_view(Rotation, *storage.entity_components[1], storage.num_entities);
			`scale_array := array_view(Scale, *storage.entity_components[2], storage.num_entities);


			`generations := array_view_dynamic(storage.generations, storage.generations.count);
			`entity_count := storage.num_entities;
			`archetype_index  := 0;
			`alive_mask  := *storage.alive_mask;

			#insert body;
		}
	}

	storage := *world.world_archetypes[1];
	{
		if storage.initialized && storage.num_entities != 0 {

			`position_array := array_view(Position, *storage.entity_components[0], storage.num_entities);
			`rotation_array := array_view(Rotation, *storage.entity_components[1], storage.num_entities);
			`scale_array := array_view(Scale, *storage.entity_components[2], storage.num_entities);


			`generations := array_view_dynamic(storage.generations, storage.generations.count);
			`entity_count := storage.num_entities;
			`archetype_index  := 1;
			`alive_mask  := *storage.alive_mask;

			#insert body;
		}
	}

}
