// Replay_Timeline is generated when a replay is loaded on the client
// It contains component tracks etc for smooth playback
// Seeking/scrubbing will simply be fastforward/backward
// Need some way to avoid iterating over all entities even the stationary ones

Component_Track :: struct {
	steps			: [..]u32;
	data_offsets 	: [..]s64;
	cursor			: u32; 	// Index of the "from" or "last" step, cursor+1 is the "to" or next step
	component_index	: u8;
}

Entity_Replay :: struct {
	entity	: ZEntity;
	tracks	: [..]Component_Track;
}

Replay_Timeline :: struct {
	entity_replays			: [..]Entity_Replay;
	entity_replay_lookup 	:   Table(ZEntity, s64, given_compare_function = entity_compare, given_hash_function = entity_hash);

	turn_timeline			: *Turn_Timeline; // The parent timeline it was generated from
}

generate_replay_timeline :: (turn_timeline: *Turn_Timeline) -> Replay_Timeline {
	replay_timeline : Replay_Timeline;	
	replay_timeline.turn_timeline = turn_timeline;
	for turn_timeline.snapshot_stream.snapshots {
		pos := cast,no_check(*Position) (turn_timeline.snapshot_stream.data.data + it.data_offset);
		print("Step: %, Position: %\n", it.step, pos.value);
	}
	
	ZLog.write_to_log(*ZLog.ZLOGGER, .REPLAY, .NONE, "Generating replay timeline...");

	for entity: turn_timeline.entities { // First create all the tracks for all the entities
		archetype_data := get_archetype_data(entity.archetype);
		offset := replay_timeline.entity_replays.count;
		array_add(*replay_timeline.entity_replays, Entity_Replay.{entity = entity});
		element_ptr := *replay_timeline.entity_replays[replay_timeline.entity_replays.count - 1];
		array_reserve(*element_ptr.tracks, archetype_data.serializeable_entity_components.count);
		for archetype_data.serializeable_entity_components {
			track : Component_Track;
			track.component_index = cast,no_check(u8) get_entity_component_index(entity.archetype, it);
			array_add(*element_ptr.tracks, track);
		}
		table_add(*replay_timeline.entity_replay_lookup, entity, offset);
	}
	ZLog.write_to_log(*ZLog.ZLOGGER, .REPLAY, .NONE, "Finished generating replay timeline");

	snapshot_stream := turn_timeline.snapshot_stream;
	
	data_cursor := snapshot_stream.snapshots[0].data_offset;
	for *snapshot: snapshot_stream.snapshots {
		entity_index, success := table_find(*replay_timeline.entity_replay_lookup, snapshot.entity);
		if !success {
			continue;
		}
		entity_replay := *replay_timeline.entity_replays[entity_index];
		archetype_data := get_archetype_data(snapshot.entity.archetype);
		for snapshot.data_components {
			component_track := *entity_replay.tracks[it];
			array_add(*component_track.steps, snapshot.step);
			array_add(*component_track.data_offsets, data_cursor);
			data_cursor += archetype_data.entity_components_sizes[it];
		}
	}
	
	for replay_timeline.entity_replays {
		for it.tracks[0].data_offsets {
			pos := cast,no_check(*Position)snapshot_stream.data.data + it;
			
		}
	}
	
	return replay_timeline;
}

update_replay_timeline :: (using self: *Replay_System) {
	snapshot_stream := *replay_timeline.turn_timeline.snapshot_stream;
	for *entity: replay_timeline.entity_replays {
		for *component_track: entity.tracks {
			if !component_track.steps.count || component_track.steps.count == 1 {
				continue component_track;
			}

			// Advance cursor forward to the correct segment for current time
			max_cursor := cast(u32)(component_track.steps.count - 2);
			while component_track.cursor < max_cursor && cast,no_check(float32)(component_track.steps[component_track.cursor + 1]) * seconds_per_step <= time {
				component_track.cursor += 1;
			}
			// Handle backward seeking
			while component_track.cursor > 0 && cast,no_check(float32)(component_track.steps[component_track.cursor]) * seconds_per_step > time {
				component_track.cursor -= 1;
			}

			cursor_last := component_track.cursor;
			cursor_next := component_track.cursor + 1;
			segment_start := cast,no_check(float32)(component_track.steps[cursor_last]) * seconds_per_step;
			segment_duration := cast,no_check(float32)(component_track.steps[cursor_next] - component_track.steps[cursor_last]) * seconds_per_step;
			t := clamp((time - segment_start) / segment_duration, 0.0, 1.0);

			last_data_offset : *void = *snapshot_stream.data[component_track.data_offsets[cursor_last]];
			next_data_offset : *void = *snapshot_stream.data[component_track.data_offsets[cursor_next]];

			archetype_data := get_archetype_data(entity.entity.archetype);
			entity_component_raw := get_entity_component_raw(*GAME_INSTANCE.active_world.world, entity.entity, component_track.component_index);

			interpolator := archetype_data.entity_component_interpolators[component_track.component_index];
			if interpolator {
				interpolator(entity_component_raw, last_data_offset, next_data_offset, t);
			} else {
				memcpy(entity_component_raw, last_data_offset, archetype_data.entity_components_sizes[component_track.component_index]);
			}
		}
	}
}