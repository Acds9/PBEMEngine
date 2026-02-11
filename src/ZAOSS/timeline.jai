Timeline_Entity_Data :: struct {
	entity			: ZEntity;
	intel_level		: u8;
	component_data	: [..]u8; // Given the archetype and intel level, serialization and deserialization will always write and read the same structure, hence no need for counts etc
}

Timeline_Frame :: struct {
	step			: u32;
	entity_count	: u32;
	entity_data		: [..]Timeline_Entity_Data;
}

Timeline_Checkpoint :: struct {
	step			: u32;
	entity_count	: u32;
	entity_data		: [..]Timeline_Entity_Data; 
}

Timeline_Step :: struct {
	index	: u32;

	Timeline_Step_Data :: union {
		checkpoint	: Timeline_Checkpoint;
		frame		: Timeline_Frame;
	}
	step_data	: Timeline_Step_Data;
	orders		: [..]Order;
}

Turn_Timeline :: struct {
	steps			: [..]Timeline_Step;

	step_start		: u32;
	step_end		: u32; 

	current_step	: u32;
}

initialize_timeline :: (timeline: *Turn_Timeline, step_start: u32, step_end: u32) {
	timeline.step_start = step_start;
	timeline.step_end = step_end;
	timeline.current_step = step_start;
	array_resize(*timeline.steps, step_end-step_start);
}

serialize_timeline_checkpoint :: (dest: *[..]u8, src: *Timeline_Checkpoint) {
	serialize_to_buffer(dest, *src.step);
	serialize_to_buffer(dest, *src.entity_count);
	serialize_to_buffer(dest, *src.entity_data.count, size_of(s64)); // Data size
	serialize_to_buffer(dest, src.entity_data.data, src.entity_data.count);
}

deserialize_timeline_checkpoint :: (dest: *Timeline_Checkpoint, src: []u8, offset: *s64) {
	deserialize_from_buffer(*dest.step, src, offset);
	deserialize_from_buffer(*dest.entity_count, src, offset);

	data_size : s64;
	deserialize_from_buffer(*data_size, src, offset);
	array_resize(*dest.entity_data, data_size);
  	deserialize_from_buffer(dest.entity_data.data, src, offset, data_size);
}

serialize_entity :: (dest: *[..]u8, world: *ZWorld, intel_level: u8, entity: ZEntity) {
	archetype : *Archetype_Storage = *world.world_archetypes[entity.archetype];
	// Step_Entity_Data schema
	serialize_to_buffer(dest, *entity.index);
	serialize_to_buffer(dest, *entity.archetype);
	serialize_to_buffer(dest, *entity.gen);
	serialize_to_buffer(dest, *intel_level);
	// Don't need component count, archetypes are the same across client and server
	offset : s64;
	serialize_entity_component_data(dest, entity, world, intel_level, *offset);
}

create_timeline_entity_data :: (dest: *Timeline_Entity_Data, world: *ZWorld, src: ZEntity, intel_level: u8) {
	dest.entity = src;
	dest.intel_level = intel_level;
	offset : s64;
	serialize_entity_component_data(*dest.component_data, src, world, intel_level, *offset);
}

spawn_from_timeline_entity_data :: (data: *Timeline_Entity_Data, world: *ZWorld) {
	entity := create_entity(world, get_archetype(data.entity.archetype), data.entity.index, data.entity.gen);
	offset : s64;
	deserialize_entity_component_data(entity, world, data.component_data, data.intel_level, *offset);
}

deserialize_entity :: (world: *ZWorld, src: []u8, offset: *s64) {
	entity_data	: Timeline_Entity_Data;

	deserialize_from_buffer(*entity_data.entity.index, src, offset); 
	deserialize_from_buffer(*entity_data.entity.archetype, src, offset); 
	deserialize_from_buffer(*entity_data.entity.gen, src, offset); 
	deserialize_from_buffer(*entity_data.intel_level, src, offset); 

	archetype_data : *Archetype_Data = *ARCHETYPE_DATABASE[entity_data.entity.archetype];
	component_data_size := archetype_data.component_data_size_intel[entity_data.intel_level];
	array_resize(*entity_data.component_data, component_data_size);
	deserialize_from_buffer(*entity_data.component_data, src, offset, component_data_size);
}

create_timeline_checkpoint :: (dest: *Timeline_Checkpoint, step: u32, world: *ZWorld) {
	dest.step = step;
	dest.entity_count = xx world.world_entities.count;
	for world.world_entities {
		create_timeline_entity_data(*dest.entity_data[it_index], world, it, 255);
	}
}

create_timeline_checkpoint_simulation :: (dest: *Timeline_Checkpoint, simulation: *Simulation_Instance) {
	world := *simulation.game_world.world;
	create_timeline_checkpoint(dest, simulation.sim_state.current_step, world);
} 

