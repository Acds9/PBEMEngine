// STRUCTURE
// A turn timeline spans from x to y steps in the game. Steps are NOT relative e.g. step 0 is the start of the whole game, not the start of this turn
// Data is divided into streams. 
// 	- Orders are orders given by players. 
// 	- Snapshots are entity data which may be complete or partial to be loaded into the entity at that step. 
//	- Events are things such as entity spawning
// All of them store offset and size into the stream's data buffer which is where the data is stored in byte form
// Use subslice or the provided utility functions to access it easily
// Data sizes aren't needed for some (like orders) due to the compile-time known nature of them, but is included anyway because slices are pointer and size

Entity_Snapshot :: struct {
	entity			: ZEntity;
	step			: u32;
	intel_level		: u8;
	data_offset		: s64;
	data_size		: s64;
} @serialize

Order_Stream :: struct {
	cursor	: s64; @no_serialize
	orders	: [..]Order;
	data	: [..]u8;
} @serialize

Snapshot_Stream :: struct {
	cursor		: s64; @no_serialize
	snapshots	: [..]Entity_Snapshot;
	data		: [..]u8;
} @serialize

Event_Stream :: struct { // Not implemented yet
	cursor	: s64; @no_serialize
	events	: [..]u8;
	data	: [..]u8;
} @serialize

Turn_Timeline :: struct {
	step_start		: u32;
	step_end		: u32; 
	
	order_stream	: Order_Stream;
	snapshot_stream	: Snapshot_Stream;
	event_stream	: Event_Stream;
} @serialize

initialize_timeline :: (timeline: *Turn_Timeline, step_start: u32, step_end: u32) {
	timeline.step_start = step_start;
	timeline.step_end = step_end;
}

create_start_state_from_timeline :: (timeline: *Turn_Timeline, world: *ZWorld) {
	start_checkpoint := read_stream(*timeline.snapshot_stream, 0);
	assert(start_checkpoint.count != 0, "ERROR: Malformed turn does not start on a checkpoint, step 0 has no entity snapshots");
	for *start_checkpoint {
		spawn_from_timeline_entity_data(it, *timeline.snapshot_stream, world);
	}
}

compact_order_data :: (src: *Order_Stream) {
	temp_buffer : [..]u8;
	for *order: src.orders {
		serialize_to_buffer(*temp_buffer, src.data.data, *order.data_offset, xx order.data_count);
	}
}

read_stream :: (stream: *Order_Stream, step: u32) -> []Order {
    slice: []Order;
    start: s64 = -1;
    for stream.orders {
        if start < 0 && it.step == step {
            slice.data = stream.orders.data + it_index;
            start = it_index;
            continue;
        }
        if start >= 0 && it.step != step {
            slice.count = it_index - start;
            return slice;
        }
    }
    if start >= 0  {
		slice.count = stream.orders.count - start;
	}
    return slice;
}

read_stream :: (stream: *Snapshot_Stream, step: u32) -> []Entity_Snapshot {
    slice: []Entity_Snapshot;
    start: s64 = -1;
    for stream.snapshots {
        if start < 0 && it.step == step {
            slice.data = stream.snapshots.data + it_index;
            start = it_index;
            continue;
        }
        if start >= 0 && it.step != step {
            slice.count = it_index - start;
            return slice;
        }
    }
    if start >= 0  {
		slice.count = stream.snapshots.count - start;
	}
    return slice;
}

read_entity_data :: (snapshot: *Entity_Snapshot, data: []u8) -> []u8 {
	slice : []u8;
	slice.data = data.data + snapshot.data_offset;
	slice.count = data.count;
	return slice;
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

create_timeline_entity_data :: (dest: *Snapshot_Stream, world: *ZWorld, src: ZEntity, step: u32, intel_level: u8) {
	snapshots := *dest.snapshots;
	array_resize(snapshots, snapshots.count+1);
	snapshot : *Entity_Snapshot = *(<<snapshots)[snapshots.count-1];
	snapshot.entity = src;
	snapshot.step = step;
	snapshot.intel_level = intel_level;
	snapshot.data_offset = dest.data.count;
	snapshot.data_size = get_archetype_data_size_intel(get_archetype(src.archetype), intel_level);
	offset : s64;
	serialize_entity_component_data(*dest.data, src, world, intel_level, *offset);
}

// entity and intel level indices must match e.g. src[5] must have its intel level at intel_levels[5]
create_timeline_entity_data :: (dest: *Snapshot_Stream, world: *ZWorld, src: []ZEntity, step: u32, intel_levels: []u8) {
	snapshots := *dest.snapshots;
	array_resize(snapshots, src.count);
	offset : s64;
	// TODO: serialize_entity_component_data will resize the array for every addition, costly, need a variant that writes expecting an already sized array
	for entity: src {
		snapshot := *(<<snapshots)[snapshots.count-1];
		snapshot.entity = entity;
		snapshot.step = step;
		snapshot.intel_level = intel_levels[it_index];
		snapshot.data_offset = dest.data.count;
		snapshot.data_size = get_archetype_data_size_intel(get_archetype(entity.archetype), snapshot.intel_level); // Called twice now but it should be a jumptable, doesn't matter
		serialize_entity_component_data(*dest.data, entity, world, intel_levels[it_index], *offset);
	}
}

spawn_from_timeline_entity_data :: (src: *Entity_Snapshot, stream: *Snapshot_Stream, world: *ZWorld) {
	if src.data_offset < 0 || src.data_size < 0 {
		return;
	}
	entity := create_entity(world, get_archetype(src.entity.archetype), src.entity.index, src.entity.gen);
	data_slice := subslice(stream.data, src.data_offset, src.data_size);
	offset : s64;
	deserialize_entity_component_data(entity, world, data_slice, src.intel_level, *offset);
}

create_timeline_checkpoint :: (dest: *Snapshot_Stream, world: *ZWorld, step: u32) {
	// PLACEHOLDER
	intel_levels : [..]u8;
	array_resize(*intel_levels, world.world_entities.count);
	//
	create_timeline_entity_data(dest, world, world.world_entities, step, intel_levels);
}
