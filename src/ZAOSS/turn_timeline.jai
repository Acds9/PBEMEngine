// STRUCTURE
// A turn timeline spans from x to y steps in the game. Steps are NOT relative e.g. step 0 is the start of the whole game, not the start of this turn
// Data is divided into streams.
// 	- Orders are orders given by players.
// 	- Snapshots are entity data which may be complete or partial to be loaded into the entity at that step. A snapshot may be just position, or a dozen components.
//		- Snapshot data is stored as follows at data_offset in the stream data: [count u8][component index u8][component data][component index u8][component data]...
//		- Archetypes are compile-time known and as such the bitfield representing the presence of their entity components are also known
//	- Events are things such as entity spawning
// All of them store offset and size into the stream's data buffer which is where the data is stored in byte form
// Use subslice or the provided utility functions to access it easily
// Data sizes aren't needed for some (like orders) due to the compile-time known nature of them, but is included anyway because slices are pointer and size
//

Entity_Snapshot :: struct @serialize {
	entity			: ZEntity;
	step			: u32;
	data_offset		: s64;
	data_components	: [..]u8;
}

Order_Stream :: struct @serialize {
	cursor	: s64; @no_serialize
	orders	: [..]Order;
	data	: [..]u8;
}

Snapshot_Stream :: struct @serialize {
	cursor		: s64; @no_serialize
	snapshots	: [..]Entity_Snapshot;
	data		: [..]u8;
}

Event_Stream :: struct @serialize { // Not implemented yet
	cursor	: s64; @no_serialize
	events	: [..]u8;
	data	: [..]u8;
}

Turn_Timeline :: struct @serialize {
	step_start		: u32;
	step_end		: u32;

	order_stream	: Order_Stream;
	snapshot_stream	: Snapshot_Stream;
	event_stream	: Event_Stream;

	entities		: [..]ZEntity; // All of the entities that will exist during this timeline
}

initialize_timeline :: (timeline: *Turn_Timeline, step_start: u32, step_end: u32) {
	timeline.step_start = step_start;
	timeline.step_end = step_end;
}

create_start_state_from_timeline :: (timeline: *Turn_Timeline, world: *ZWorld) {
	create_timeline_entities(timeline, world);

	starting_snapshots := read_stream(*timeline.snapshot_stream, timeline.step_start);
	for *snapshot: starting_snapshots {
		snapshot_entity := snapshot.entity;
		archetype_data := get_archetype_data(snapshot_entity.archetype);
		archetype_storage := get_archetype_storage(world, snapshot_entity.archetype);
		count := snapshot.data_components.count;
		if count == 0 {
			continue; // No entity components to read
		}
		offset := snapshot.data_offset;
		for snapshot.data_components {
			size := archetype_data.entity_components_sizes[it];
			component_storage := *archetype_storage.entity_components[it];
			dest : *u8 = (component_storage.data.data + snapshot_entity.index * component_storage.stride);
			deserialize_from_buffer(dest, timeline.snapshot_stream.data, *offset, size);
		}
		set_entity_alive(world, snapshot_entity, true);
	}
}

create_timeline_entities :: (timeline: *Turn_Timeline, world: *ZWorld) {
	ZLog.write_to_log(*ZLog.ZLOGGER, .SIMULATION, .NONE, tprint("Creating % entities from timeline...", timeline.entities.count));
	for timeline.entities {
		create_entity(world, it.archetype, it.index, it.generation, true);
	}
	if !timeline.entities.count {
		ZLog.write_to_log(*ZLog.ZLOGGER, .SIMULATION, .NONE, tprint("WARNING: No entities found in timeline.entities"));
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