#import "File_Utilities";

#add_context headless	: bool;

GAME_STATE :: enum u8 {
	SIMULATION;
	REPLAY;
}

Game_Manifest :: struct {
	name			: string;
	game_id			: u64;
	default_step_resolution	: u32;
	default_turn_steps	 	: u32; // How many steps per turn
	total_steps		: u32;
	player_count	: u32;
	max_players		: u32;

	current_turn	: u32;

	player_list		: [..]u64;
}

Turn_Header :: struct {
	game_id			: u64;
	turn			: u32;
	step_resolution : u32;
	turn_duration 	: float32;

	frame_data		: [..]Frame_Data;
}

Frame_Data :: struct {
	frame_num		: u32;
	entity_count	: u32;
	entity_data		: [..]Entity_Data;
}

Entity_Data :: struct {
	entity			: ZEntity;
	component_count : u16;
	intel_level		: u8;
	component_data	: [..]u8;
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
	manifest := Game_Manifest.{
				name 			= name, 
				game_id			= random_get(), 
				default_step_resolution = step_resolution, 
				default_turn_steps = turn_duration_seconds * step_resolution,
				total_steps 	= time_limit_seconds * step_resolution, 
				player_count 	= 0, 
				max_players 	= max_players, 
				current_turn 	= 0};
	array_resize(*manifest.player_list, max_players);

	serialize_game_manifest(manifest, *manifest_buffer);

	game_buffer	: [..]u8;
	defer free(game_buffer.data);
	
	cwd := get_working_directory();

	serialize_to_buffer(*game_buffer, *game_id, size_of(u64));

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

	game_world : ZWorld;
	initialize_zworld(*game_world);
	setup_game_world(*game_world);
	init_state : Snapshot;
	take_snapshot(*init_state, 0, *game_world);
	state_path := tprint("%/%/%_0.%", path, TURN_FOLDER_NAME, name, TURN_EXT);
	snapshot_buffer : [..]u8;
	serialize_snapshot(*snapshot_buffer, *init_state);
	write_entire_file(state_path, snapshot_buffer.data, snapshot_buffer.count);
}

serialize_game_manifest :: (manifest: Game_Manifest, dest: *[..]u8) {
	serialize_to_buffer_string(dest, manifest.name);
	serialize_to_buffer(dest, *manifest.game_id, size_of(u64));
	serialize_to_buffer(dest, *manifest.default_step_resolution, size_of(u32));
	serialize_to_buffer(dest, *manifest.default_turn_steps, size_of(u32));
	serialize_to_buffer(dest, *manifest.total_steps, size_of(u32));
	serialize_to_buffer(dest, *manifest.player_count, size_of(u32)); // Player Count
	serialize_to_buffer(dest, *manifest.max_players, size_of(u32));
	serialize_to_buffer(dest, *manifest.current_turn, size_of(u32)); // Current Turn
	for manifest.player_list {
		serialize_to_buffer(dest, *it, size_of(u64));
	}
}

deserialize_game_manifest :: (data: []u8) -> Game_Manifest {
	manifest : Game_Manifest;
	offset : s64 = 0;

	manifest.name = deserialize_from_buffer_string(data, *offset);
    
    deserialize_from_buffer(*manifest.game_id, data, *offset, size_of(u64));
    deserialize_from_buffer(*manifest.default_step_resolution, data, *offset, size_of(u32));
	deserialize_from_buffer(*manifest.default_turn_steps, data, *offset, size_of(u32));
    deserialize_from_buffer(*manifest.total_steps, data, *offset, size_of(u32));
    deserialize_from_buffer(*manifest.player_count, data, *offset, size_of(u32));
    deserialize_from_buffer(*manifest.max_players, data, *offset, size_of(u32));
    deserialize_from_buffer(*manifest.current_turn, data, *offset, size_of(u32));
    
    array_resize(*manifest.player_list, manifest.max_players);
    for 0..manifest.max_players-1 {
        deserialize_from_buffer(*manifest.player_list[it], data, *offset, size_of(u64));
    }

	return manifest;
}