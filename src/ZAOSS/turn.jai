#import "File_Utilities";

#add_context headless	: bool;

// TODO: move these out of here
MAX_INTEL_LEVEL :: 9;
DEBUG_INTEL_LEVEL :: 10;

GAME_STATE :: enum u8 {
	SIMULATION;
	REPLAY;
}

Manifest_File :: struct {
	name			: string;
	game_id			: u64;
	default_step_resolution	: u32;
	default_turn_steps	 	: u32; // How many steps per turn
	total_steps		: u32;
	player_count	: u32;
	max_players		: u32;
	current_turn	: u32;
}

Game_File :: struct {
	name	: string; //Duplicated with Manifest_File for ease of use
	player_list		: [..]u64;
}

Turn_File :: struct {
	game			: string;
	turn			: u32;
	start_step		: u32;
	end_step		: u32;
	step_resolution	: u32;

	timeline		: Turn_Timeline;
}

/*
serialize_frame :: (frame: *Frame_Data) {
	world := *GAME_INSTANCE.world;
	array_resize(*frame.entity_data, world.world_entities.count);
	for entity: world.world_entities {
		entity_data : *Entity_Data = *frame.entity_data[it_index];
		entity_data.entity = entity;
		entity_data.intel_level = 0;

		position_component := get_entity_component(world, entity, Position);
		serialize_component(position_component, *entity_data.component_data);
	}
}*/

setup_game_world :: (world: *ZWorld) {
	create_entity_batch(world, Archetype_Ship, 3); 
}

create_game :: (name: string, step_resolution: u32, turn_duration_seconds: u32, time_limit_seconds: u32, max_players: u32) {
	manifest_buffer : [..]u8;
	defer free(manifest_buffer.data);
	game_id := random_get();
	manifest := Manifest_File.{
				name 			= name, 
				game_id			= random_get(), 
				default_step_resolution = step_resolution, 
				default_turn_steps = turn_duration_seconds * step_resolution,
				total_steps 	= time_limit_seconds * step_resolution, 
				player_count 	= 0, 
				max_players 	= max_players, 
				current_turn 	= 0};
	serialize_manifest_file(*manifest_buffer, *manifest);

	game_buffer	: [..]u8;
	defer free(game_buffer.data);
	
	player_list : [..]u64;
	array_resize(*player_list, max_players);
	serialize_to_buffer_string(*game_buffer, name);
	serialize_to_buffer(*game_buffer, *max_players, size_of(u32));
	serialize_to_buffer(*game_buffer, *player_list, player_list.count * size_of(u64));

	cwd := get_working_directory();
	path := tprint("%/%/%", cwd, GAME_FOLDER_NAME, name);
	if ensure_directory_exists(path) {
		mft_path := tprint("%/%.%", path, name, MANIFEST_EXT);
		game_path := tprint("%/%.%", path, name, GAME_EXT);
		
		write_entire_file(mft_path, manifest_buffer.data, manifest_buffer.count);
		write_entire_file(game_path, game_buffer.data, game_buffer.count);

		turn_path := tprint("%/%", path, TURN_FOLDER_NAME);
		ensure_directory_exists(turn_path);

		order_path := tprint("%/%", path, ORDER_FOLDER_NAME);
		ensure_directory_exists(order_path);
	}

	start_turn : Turn_File;
	start_turn.game = name;
	start_turn.turn	= 0;
	start_turn.start_step = 0;
	start_turn.end_step = manifest.default_turn_steps;
	start_turn.step_resolution = step_resolution;

	game_world : ZWorld;
	initialize_zworld(*game_world);
	setup_game_world(*game_world);

	initialize_timeline(*start_turn.timeline, 0, manifest.default_turn_steps);

	checkpoint  := *start_turn.timeline.steps[0].step_data.checkpoint;
	create_timeline_checkpoint(checkpoint, 0, *game_world);

	state_path := tprint("%/%/%_0.%", path, TURN_FOLDER_NAME, name, TURN_EXT);
	snapshot_buffer : [..]u8;
	offset : s64;
	serialize_timeline_checkpoint(*snapshot_buffer, checkpoint);
	write_entire_file(state_path, snapshot_buffer.data, snapshot_buffer.count);
}

serialize_manifest_file :: (dest: *[..]u8, src: *Manifest_File) {
	serialize_to_buffer_string(dest, src.name);
	serialize_to_buffer(dest, *src.game_id, size_of(u64));
	serialize_to_buffer(dest, *src.default_step_resolution, size_of(u32));
	serialize_to_buffer(dest, *src.default_turn_steps, size_of(u32));
	serialize_to_buffer(dest, *src.total_steps, size_of(u32));
	serialize_to_buffer(dest, *src.player_count, size_of(u32)); // Player Count
	serialize_to_buffer(dest, *src.max_players, size_of(u32));
	serialize_to_buffer(dest, *src.current_turn, size_of(u32)); // Current Turn
}

deserialize_manifest_file :: (dest: *Manifest_File, src: []u8, offset: *s64) {
	dest.name = deserialize_from_buffer_string(src, offset);
    deserialize_from_buffer(*dest.game_id, src, offset);
    deserialize_from_buffer(*dest.default_step_resolution, src, offset);
	deserialize_from_buffer(*dest.default_turn_steps, src, offset);
    deserialize_from_buffer(*dest.total_steps, src, offset);
    deserialize_from_buffer(*dest.player_count, src, offset);
    deserialize_from_buffer(*dest.max_players, src, offset);
    deserialize_from_buffer(*dest.current_turn, src, offset);
}

serialize_game_file :: (dest: *[..]u8, src: *Game_File) {
	serialize_to_buffer_string(dest, src.name);
	serialize_to_buffer(dest, *src.player_list.count, size_of(s64));
	for src.player_list {
		serialize_to_buffer(dest, *it, size_of(u64));
	}
}

deserialize_game_file :: (dest: *Game_File, src: []u8, offset: *s64) {
	dest.name = deserialize_from_buffer_string(src, offset);
    count : s64;
	deserialize_from_buffer(*count, src, offset);
	array_resize(*dest.player_list, count);
	for *dest.player_list {
		deserialize_from_buffer(it, src, offset);
	}
}