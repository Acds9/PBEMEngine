
// Query Executor for Query_Position_Randomizer
execute_Query_Position_Randomizer :: (world: *ZWorld, $body: Code) #expand {
	storage : *Archetype_Storage;
	`generations : []u16;
	`entity_count : s64;
	`archetype_index : u16;
	`alive_mask : *Bit_Field(MAX_ENTITIES_PER_ARCHETYPE);
	`position_array :[]Position;
	storage = *world.world_archetypes[1];
	{
		if storage.initialized && storage.num_entities != 0 {

			`position_array = array_view(Position, *storage.entity_components[0], storage.num_entities);


			`generations = array_view_dynamic(storage.generations, storage.generations.count);
			`entity_count = storage.num_entities;
			`archetype_index  = 1;
			`alive_mask  = *storage.alive_mask;

			#insert body;
		}
	}

}

// Query Executor for Query_Update_Render_Proxy
execute_Query_Update_Render_Proxy :: (world: *ZWorld, $body: Code) #expand {
	storage : *Archetype_Storage;
	`generations : []u16;
	`entity_count : s64;
	`archetype_index : u16;
	`alive_mask : *Bit_Field(MAX_ENTITIES_PER_ARCHETYPE);
	`position_array :[]Position;
	`rotation_array :[]Rotation;
	`scale_array :[]Scale;
	`mesh_instance_address_array :[]Mesh_Instance_Address;
	storage = *world.world_archetypes[1];
	{
		if storage.initialized && storage.num_entities != 0 {

			`position_array = array_view(Position, *storage.entity_components[0], storage.num_entities);
			`rotation_array = array_view(Rotation, *storage.entity_components[1], storage.num_entities);
			`scale_array = array_view(Scale, *storage.entity_components[2], storage.num_entities);
			`mesh_instance_address_array = array_view(Mesh_Instance_Address, *storage.entity_components[3], storage.num_entities);


			`generations = array_view_dynamic(storage.generations, storage.generations.count);
			`entity_count = storage.num_entities;
			`archetype_index  = 1;
			`alive_mask  = *storage.alive_mask;

			#insert body;
		}
	}

}

// Query Executor for Query_Debug_Draw_Point_Light
execute_Query_Debug_Draw_Point_Light :: (world: *ZWorld, $body: Code) #expand {
	storage : *Archetype_Storage;
	`generations : []u16;
	`entity_count : s64;
	`archetype_index : u16;
	`alive_mask : *Bit_Field(MAX_ENTITIES_PER_ARCHETYPE);
	`position_array :[]Position;
	`point_light_component_array :[]Point_Light_Component;
	storage = *world.world_archetypes[0];
	{
		if storage.initialized && storage.num_entities != 0 {

			`position_array = array_view(Position, *storage.entity_components[0], storage.num_entities);
			`point_light_component_array = array_view(Point_Light_Component, *storage.entity_components[1], storage.num_entities);


			`generations = array_view_dynamic(storage.generations, storage.generations.count);
			`entity_count = storage.num_entities;
			`archetype_index  = 0;
			`alive_mask  = *storage.alive_mask;

			#insert body;
		}
	}

}
