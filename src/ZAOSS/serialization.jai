serialize_to_buffer_string :: (dest: *[..]u8, src: string) -> s64 {
	len := cast(s32) src.count;
    offset := serialize_to_buffer(dest, *len, size_of(s32)); 
    serialize_to_buffer(dest, src.data, src.count);
	return offset;
}

serialize_to_buffer :: (dest: *[..]u8, src: *void, count: s64) -> s64 {
    offset := dest.count;
    array_resize(dest, offset + count);
    memcpy(dest.data + offset, src, count);
	return offset;
}

serialize_to_buffer :: (dest: *[..]u8, src: *$T) -> s64 {
    offset := dest.count;
    array_resize(dest, offset + size_of(T)); // TODO: we resize the array a lot this way, maybe should have a version that assumes the array already has room?
    memcpy(dest.data + offset, src, size_of(T));
	return offset;
}

serialize_to_buffer :: (dest: *[..]u8, src: *void, offset: *s64, count: s64) {
    if dest.count <= <<offset + count {
		array_resize(dest, <<offset + count);
	}
    memcpy(dest.data + <<offset, src, count);
    <<offset += count;
}

deserialize_from_buffer :: (dest: *void, src: []u8, offset: *s64, count: s64) {
	memcpy(dest, src.data + <<offset, count);
    <<offset += count;
}

deserialize_from_buffer :: (dest: *$T, src: []u8, offset: *s64) {
	memcpy(dest, src.data + <<offset, size_of(T));
    <<offset += size_of(T);
}

deserialize_from_buffer_string :: (src: []u8, offset: *s64) -> string {
    len : s32;
	deserialize_from_buffer(*len, src, offset, size_of(s32));
    result : string;
    result.count = len;
    result.data = alloc(len);
    memcpy(result.data, src.data + <<offset, len);
    <<offset += len;
    return result;
}



////////////////////////////////////
// SERIALIZATION QUEUE SYSTEM //////
////////////////////////////////////
// MOVE THIS OUT LATER
#import "Hash_Table";

Simulation_Record_System :: struct {
	Snapshot_Entry :: struct {
		components 	: [..]Type;
		size		: s64;
	}
	snapshot_queue : Table(u64, Snapshot_Entry);
	total_queue_size : s64;
}

record_snapshot :: (using self: *Simulation_Record_System, entity: ZEntity, component_type: ..$Type) {
	int_entity := entity_to_u64(entity);
	entry := table_find_pointer(*snapshot_queue, int_entity);
	if !entry {
		entry = table_add(*snapshot_queue, int_entity, .{});
	} else { // If it does already exist, check that we haven't already queued it
		for component_type { // TODO: this bails if only ONE component has already been added right now
			if array_contains(entry.components, it) { // Not the fastest, but should be fine
				return;
			}
		}
	}
	start_idx := entry.components.count;
	array_resize(*entry.components, entry.components.count + component_type.count);
	archetype_data := get_archetype_data(entity.archetype);
	for component_type {
		_, serializeable := get_serializeable_entity_component_index(entity.archetype, it);
		if  !serializeable {
			print("WARNING: Attempted to serialize component % of archetype %, but it is not in the serializeable entity component array of the archetype, skipping...", it, archetype_data.name);
			continue;
		}
		entry.size +=  get_entity_component_size(it); 
		total_queue_size +=get_entity_component_size(it);
		entry.components[start_idx] = it;
		start_idx += 1;
	}
}
/*
for sim_entry.master_timeline.snapshot_stream.snapshots {
			pos := cast,no_check(*Position) sim_entry.master_timeline.snapshot_stream.data.data + it.data_offset;
			print("Step: %, Position: %\n", it.step, pos.value);
		}
*/
record_checkpoint :: (using self: *Simulation_Record_System, entity: ZEntity) { // TODO: needs to be handled in flush_record_queue
	int_entity := entity_to_u64(entity);
	entry := table_find_pointer(*snapshot_queue, int_entity);
	archetype_data := get_archetype_data(entity.archetype);
	if !entry {
		entry = table_add(*snapshot_queue, int_entity, .{});
	} else { 
		array_free(entry.components); // If we're taking a checkpoint, we just want to overwrite whatever was there before
		<<entry = .{};
	}
	array_reserve(*entry.components, archetype_data.serializeable_entity_components.count);
	array_add(*entry.components, ..archetype_data.serializeable_entity_components);
	entry.size = archetype_data.component_data_size_intel[archetype_data.component_data_size_intel.count-1];
	total_queue_size += entry.size;
}

record_world_checkpoint :: (using self: *Simulation_Record_System, world: *ZWorld) {
	for world.world_entities {
		record_checkpoint(self, it);
	}
}


flush_record_queue :: (using self: *Simulation_Record_System, world: *ZWorld, step: u32, timeline: *Turn_Timeline) {
	// DIAG: Check ALL existing snapshot data on EVERY step (including non-snapshot steps)
	snapshot_stream_check := *timeline.snapshot_stream;
	for snap: snapshot_stream_check.snapshots {
		p := cast,no_check(*Position)(snapshot_stream_check.data.data + snap.data_offset);
		if p.value.x == 0 && p.value.y == 0 && p.value.z == 0 {
			print("!!! CORRUPTION DETECTED at step % (before flush): snapshot step=% data_offset=% has ZERO position. data.data=%, data.count=%\n",
				step, snap.step, snap.data_offset, snapshot_stream_check.data.data, snapshot_stream_check.data.count);
		}
	}

	if !snapshot_queue.count {
		return;
	}
	snapshot_stream := *timeline.snapshot_stream;
	offset : s64 = snapshot_stream.data.count; // For writing into the snapshot shared data buffer

	snapshot_iterator := snapshot_stream.snapshots.count;
	old_data_ptr := snapshot_stream.data.data;
	old_data_count := snapshot_stream.data.count;
	old_snapshots_ptr := snapshot_stream.snapshots.data;
	array_resize(*snapshot_stream.snapshots, snapshot_stream.snapshots.count + snapshot_queue.count); // Add count for new snapshots
	array_resize(*snapshot_stream.data, snapshot_stream.data.count + total_queue_size); // And the total size of the queue entries

	// DIAG: Verify ALL previously written data survived the resize
	if old_data_count > 0 {
		corruption_found := false;
		for prev: 0..snapshot_iterator-1 {
			prev_snap := snapshot_stream.snapshots[prev];
			p := cast,no_check(*Position)(snapshot_stream.data.data + prev_snap.data_offset);
			if p.value.x == 0 && p.value.y == 0 && p.value.z == 0 {
				print("!!! CORRUPTION after resize at step %: snapshot[%] (step %) data_offset=% has ZERO position. data moved: % -> %, snapshots moved: % -> %\n",
					step, prev, prev_snap.step, prev_snap.data_offset,
					old_data_ptr, snapshot_stream.data.data,
					old_snapshots_ptr, snapshot_stream.snapshots.data);
				corruption_found = true;
			}
		}
	}

	for snapshot_queue {
		snapshot := *snapshot_stream.snapshots[snapshot_iterator];
		<<snapshot = .{};
		snapshot.entity = u64_to_entity(it_index);
		snapshot.step = step;
		snapshot.data_offset = offset;

		array_reserve(*snapshot.data_components, it.components.count);
		// sort entry components by their archetype component index before serializing, we do this inline to avoid lambda limitations and these arrays are tiny so it's fine TODO: check that it's actually fine
		for i: 1..it.components.count-1 {
			j := i;
			while j > 0 && get_serializeable_entity_component_index(snapshot.entity.archetype, it.components[j]) < get_serializeable_entity_component_index(snapshot.entity.archetype, it.components[j-1]) {
				tmp := it.components[j];
				it.components[j] = it.components[j-1];
				it.components[j-1] = tmp;
				j -= 1;
			}
		}

		for component_type: it.components {
			array_add(*snapshot.data_components, get_serializeable_entity_component_index(snapshot.entity.archetype, component_type));
			data_ptr, data_size := get_entity_component_raw(world, snapshot.entity, component_type);
			assert(data_ptr != null, tprint("Attempted to fetch an entity component % that was not found in the archetype %", component_type, snapshot.entity.archetype));

			write_offset := <<*offset; // Save offset BEFORE serialize advances it
			serialize_to_buffer(*snapshot_stream.data, data_ptr, *offset, data_size);

			// DIAG: Verify source data and readback for EVERY snapshot step
			readback := cast,no_check(*Position)(snapshot_stream.data.data + write_offset);
			source := (cast,no_check(*Position)data_ptr).value;
			if source.x == 0 && source.y == 0 && source.z == 0 {
				print("!!! ZERO SOURCE at step %: entity component data is {0,0,0}, write_offset=%, data.data=%\n", step, write_offset, snapshot_stream.data.data);
			}
			if readback.value.x != source.x || readback.value.y != source.y || readback.value.z != source.z {
				print("!!! WRITE MISMATCH at step %: src=%, readback=%, write_offset=%, data.data=%\n", step, source, readback.value, write_offset, snapshot_stream.data.data);
			}
		}

		added : bool;
		for timeline.entities { // TODO: this is pretty awful for every single entity over every entity recorded, optimize it
			if entity_to_u64(it) == entity_to_u64(snapshot.entity) {
				added = true;
			}
		}
		if !added {
			array_add(*timeline.entities, snapshot.entity);
		}

		snapshot_iterator += 1;
	}

	// DIAG: After all writes, verify ALL snapshots in stream
	for snap: snapshot_stream.snapshots {
		p := cast,no_check(*Position)(snapshot_stream.data.data + snap.data_offset);
		if p.value.x == 0 && p.value.y == 0 && p.value.z == 0 {
			print("!!! END-FLUSH step %: snapshot step=% data_offset=% has ZERO position. data.data=%, data.count=%\n",
				step, snap.step, snap.data_offset, snapshot_stream.data.data, snapshot_stream.data.count);
		}
	}

	for snapshot_queue {
		array_free(it.components);
	}
	table_reset(*snapshot_queue);
	total_queue_size = 0;
}