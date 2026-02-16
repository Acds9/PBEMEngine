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

Timeline_Checkpoint :: struct { // TODO: right now Frame and Checkpoint are identical, if they still are in the future, merge them
	step			: u32;
	entity_count	: u32;
	entity_data		: [..]Timeline_Entity_Data; 
}

Timeline_Step :: struct {
	index	: u32;

	is_checkpoint	: bool;
	Timeline_Step_Data :: union {
		checkpoint	: Timeline_Checkpoint;
		frame		: Timeline_Frame;
	}
	step_data	: Timeline_Step_Data;
	orders		: [..]Order;
}

Turn_Timeline :: struct {
	step_start		: u32;
	step_end		: u32; 

	steps			: [..]Timeline_Step;
}

initialize_timeline :: (timeline: *Turn_Timeline, step_start: u32, step_end: u32) {
	timeline.step_start = step_start;
	timeline.step_end = step_end;
	array_resize(*timeline.steps, (step_end+1)-step_start); // Inclusive
}

serialize_turn_timeline :: (dest: *[..]u8, src: *Turn_Timeline) {
	serialize_to_buffer(dest, *src.step_start);
	serialize_to_buffer(dest, *src.step_end);
	serialize_to_buffer(dest, *src.steps.count);
	for *src.steps {
		serialize_timeline_step(dest, it);
	}
}

deserialize_turn_timeline :: (dest: *Turn_Timeline, src: []u8, offset: *s64) {
	deserialize_from_buffer(*dest.step_start, src, offset);
	deserialize_from_buffer(*dest.step_end, src, offset);
	step_count : s64;
	deserialize_from_buffer(*step_count, src, offset);
	array_resize(*dest.steps, step_count);
	for *dest.steps {
		deserialize_timeline_step(it, src, offset);
	}
}

serialize_timeline_step :: (dest: *[..]u8, src: *Timeline_Step) {
	serialize_to_buffer(dest, *src.index);
	serialize_to_buffer(dest, *src.is_checkpoint);
	if src.is_checkpoint {
		serialize_timeline_checkpoint(dest, *src.step_data.checkpoint);
	} else {
		serialize_timeline_frame(dest, *src.step_data.frame);
	}
	serialize_to_buffer(dest, *src.orders.count);
	serialize_to_buffer(dest, *src.orders.data);
}

deserialize_timeline_step :: (dest: *Timeline_Step, src: []u8, offset: *s64) {
	deserialize_from_buffer(*dest.index, src, offset);
	deserialize_from_buffer(*dest.is_checkpoint, src, offset);
	if dest.is_checkpoint {
		deserialize_timeline_checkpoint(*dest.step_data.checkpoint, src, offset);
	} else {
		deserialize_timeline_frame(*dest.step_data.frame, src, offset);
	}
	data_size : s64;
	deserialize_from_buffer(*data_size, src, offset);
	array_resize(*dest.orders, data_size);
  	deserialize_from_buffer(dest.orders.data, src, offset, data_size);
}

serialize_timeline_frame :: (dest: *[..]u8, src: *Timeline_Frame) {
	serialize_to_buffer(dest, *src.step);
	serialize_to_buffer(dest, *src.entity_count);
	serialize_to_buffer(dest, *src.entity_data.count, size_of(s64));

	for *src.entity_data {
		serialize_timeline_entity_data(dest, it);
	}
}

deserialize_timeline_frame :: (dest: *Timeline_Frame, src: []u8, offset: *s64) {
	deserialize_from_buffer(*dest.step, src, offset);
	deserialize_from_buffer(*dest.entity_count, src, offset);

	data_size : s64;
	deserialize_from_buffer(*data_size, src, offset);
	array_resize(*dest.entity_data, data_size);
	for *dest.entity_data {
		deserialize_timeline_entity_data(it, src, offset);
	}
}

serialize_timeline_checkpoint :: (dest: *[..]u8, src: *Timeline_Checkpoint) {
	serialize_to_buffer(dest, *src.step);
	serialize_to_buffer(dest, *src.entity_count);
	serialize_to_buffer(dest, *src.entity_data.count, size_of(s64)); // Data size

	for *src.entity_data {
		serialize_timeline_entity_data(dest, it);
	}
}

deserialize_timeline_checkpoint :: (dest: *Timeline_Checkpoint, src: []u8, offset: *s64) {
	deserialize_from_buffer(*dest.step, src, offset);
	deserialize_from_buffer(*dest.entity_count, src, offset);

	data_size : s64;
	deserialize_from_buffer(*data_size, src, offset);
	array_resize(*dest.entity_data, data_size);
	for *dest.entity_data {
		deserialize_timeline_entity_data(it, src, offset);
	}
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

serialize_timeline_entity_data :: (dest: *[..]u8, src: *Timeline_Entity_Data) {
	serialize_to_buffer(dest, *src.entity.index);
	serialize_to_buffer(dest, *src.entity.archetype);
	serialize_to_buffer(dest, *src.entity.gen);
	serialize_to_buffer(dest, *src.intel_level);
	serialize_to_buffer(dest, src.component_data.data, src.component_data.count);
}

deserialize_timeline_entity_data :: (dest: *Timeline_Entity_Data, src: []u8, offset: *s64) {
	deserialize_from_buffer(*dest.entity.index, src, offset); 
	deserialize_from_buffer(*dest.entity.archetype, src, offset); 
	deserialize_from_buffer(*dest.entity.gen, src, offset); 
	deserialize_from_buffer(*dest.intel_level, src, offset); 
	deserialize_entity_component_data(*dest.component_data, src, dest.entity.archetype, dest.intel_level, offset);
}

create_timeline_checkpoint :: (dest: *Timeline_Checkpoint, step: u32, world: *ZWorld) {
	dest.step = step;
	dest.entity_count = xx world.world_entities.count;
	array_resize(*dest.entity_data, dest.entity_count);
	for world.world_entities {
		create_timeline_entity_data(*dest.entity_data[it_index], world, it, 255);
	}
}

create_timeline_checkpoint_simulation :: (dest: *Timeline_Checkpoint, simulation: *Simulation_Instance) {
	world := *simulation.game_world.world;
	create_timeline_checkpoint(dest, simulation.sim_state.current_step, world);
} 

