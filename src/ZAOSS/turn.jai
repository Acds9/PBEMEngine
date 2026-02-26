#import "File_Utilities";

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
} @serialize

Game_File :: struct {
	name	: string; //Duplicated with Manifest_File for ease of use
	player_list		: [..]u64;
} @serialize

setup_game_world :: (world: *ZWorld) {
	create_entity_batch(world, Archetype_Ship, 1); 
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
	serialize(*manifest_buffer, *manifest);

	game_buffer	: [..]u8;
	defer free(game_buffer.data);
	
	player_list : [..]u64;
	array_resize(*player_list, max_players);
	serialize_to_buffer_string(*game_buffer, name);
	serialize_to_buffer(*game_buffer, *max_players, size_of(u32));
	serialize_to_buffer(*game_buffer, *player_list, player_list.count * size_of(u64));

	path := tprint("%/%", GAME_FOLDER_PATH, name);
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
	initialize_zworld(*game_world, .SIMULATION);
	setup_game_world(*game_world);

	initialize_timeline(*start_turn.timeline, 0, 0);

	create_timeline_checkpoint(*start_turn.timeline.snapshot_stream, *game_world, 0);

	turn_path := tprint("%/%/%_0.%", path, TURN_FOLDER_NAME, name, TURN_EXT);
	turn_buffer : [..]u8;
	offset : s64;
	serialize(*turn_buffer, *start_turn);
	write_entire_file(turn_path, turn_buffer.data, turn_buffer.count);
}

write_to_disk_turn :: (src: *Turn_File, path: string) {
	data_buffer : [..]u8;
	defer free(data_buffer.data);

	serialize(*data_buffer, src);
	write_entire_file(path, data_buffer.data, data_buffer.count);
}

write_to_disk_turn :: (src: *Turn_File) {
	path := get_turn_file_path(src.game, src.turn);
	write_to_disk_turn(src, path);
}

read_from_disk_turn :: (dest: *Turn_File, path: string) {
	contents, success := read_entire_file(path);
    assert(success, "Could not read turn at path %\n", path);
	offset : s64;
    deserialize(dest, xx contents, *offset);
}

read_from_disk_turn :: (dest: *Turn_File, game: string, turn: u32) {
	path := get_turn_file_path(game, turn);
	read_from_disk_turn(dest, path);
}