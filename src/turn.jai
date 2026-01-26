#import "File_Utilities";

GAME_FOLDER_NAME :: "games";
TURN_FOLDER_NAME :: "turns";
ORDER_FOLDER_NAME :: "orders";

GAME_FOLDER_PATH :: #run -> string {
	cwd := get_working_directory();
	return sprint("%/%", cwd, GAME_FOLDER_NAME);
}

GAME_STATE :: enum u8 {
	SIMULATION;
	REPLAY;
}

Game_Manifest :: struct {
	name			: string;
	game_id			: u64;
	tick_rate		: s32;
	duration		: s32;
	player_count	: s32;
	max_players		: s32;

	current_turn	: s32;

	player_list		: [..]u64;
}

Game_File :: struct {
	name			: string;
}

Turn_Header :: struct {
	game_id			: u64;
	turn			: u32;
	tick_rate 		: u32;
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

Simulation_System :: struct {
	game_id			: u64;
	turn			: u32;
	tick_rate		: u32;
	turn_duration	: u32;
	total_steps		: u32;
	
	sim_delta_time	: float64;
	current_time 	: float64;
	current_step	: u32;
	
	current_turn	: Turn_Header;

	initialize :: (using self: *Simulation_System) {
		sim_delta_time = 1.0 / tick_rate;
		total_steps = turn_duration*tick_rate;
	}
}

simulate_turn :: (using self: *Simulation_System) {
	while current_step < total_steps {
		serialize_frame(*current_turn.frame_data[current_step]);

		current_time += sim_delta_time;
		current_step += 1;
	}
	write_entire_file("", *current_turn, 1);
}

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
}

// TODO: need an event system and some sort of timeline

create_game :: (name: string, tick_rate: s32, duration_seconds: s32, max_players: u32) {
	manifest_buffer : [..]u8;
	defer free(manifest_buffer.data);
	zero : s32 = 0;
	zero_64 : u64 = 0;
	game_id := random_get();
	serialize_to_buffer_string(*manifest_buffer, name);
	serialize_to_buffer(*manifest_buffer, *game_id, size_of(u64));
	serialize_to_buffer(*manifest_buffer, *tick_rate, size_of(s32));
	serialize_to_buffer(*manifest_buffer, *duration_seconds, size_of(s32));
	serialize_to_buffer(*manifest_buffer, *zero, size_of(s32)); // Player Count
	serialize_to_buffer(*manifest_buffer, *max_players, size_of(s32));
	serialize_to_buffer(*manifest_buffer, *zero, size_of(s32)); // Current Turn
	for 0..max_players-1 {
		serialize_to_buffer(*manifest_buffer, *zero_64, size_of(u64));
	}

	game_buffer	: [..]u8;
	defer free(game_buffer.data);
	
	cwd := get_working_directory();

	serialize_to_buffer(*game_buffer, *game_id, size_of(u64));

	path := sprint("%/%/%", cwd, GAME_FOLDER_NAME, name);
	defer free(path);
	if ensure_directory_exists(path) {
		mft_path := sprint("%/%.mft", path, name);
		defer free(mft_path);
		game_path := sprint("%/%.game", path, name);
		defer free(game_path);
		write_entire_file(mft_path, manifest_buffer.data, manifest_buffer.count);
		write_entire_file(game_path, game_buffer.data, game_buffer.count);

		turn_path := sprint("%/%", path, TURN_FOLDER_NAME);
		defer free(turn_path);
		ensure_directory_exists(turn_path);
		order_path := sprint("%/%", path, ORDER_FOLDER_NAME);
		defer free(order_path);
		ensure_directory_exists(order_path);
	}
}

ensure_directory_exists :: (path: string) -> bool {
    if !path || file_exists(path) {
		return true;
	}
    
    // Ensure it exists first
    parent := path_strip_filename(path);
    if parent.count && parent != path {
        if !ensure_directory_exists(parent) {
			 return false;
		}
    }
    
    make_directory_if_it_does_not_exist(path);
    return file_exists(path);
}

read_manifest_name :: (name: string) -> Game_Manifest {
	manifest_paths := file_list_ext(GAME_FOLDER_PATH, ".mft", true);
	for path: manifest_paths {
		_, filename, _, _ := path_decomp(path);
		if equal(name, filename) {
			return read_manifest(path);
		}
	}
	return .{};
}

read_all_manifests :: (folder: string) -> [..]Game_Manifest { // TODO: passing by copy, could be quite a few bytes, maybe fix?
	manifests : [..]Game_Manifest;
	manifest_paths := file_list_ext(folder, ".mft", true);
	defer free(manifest_paths.data);
	
	if !manifest_paths.count {
		return manifests;
	}
	array_resize(*manifests, manifest_paths.count);
	read_success : bool;
	for file: manifest_paths {
		manifests[it_index], read_success = read_manifest(file);
		if !read_success {
			panic(sprint("Could not read manifest %", file));
		}
	}
	return manifests;
}

read_manifest :: (path: string) -> Game_Manifest, bool {
	contents, success := read_entire_file(path);
    if !success {
		return .{}, false;
	}

	manifest: Game_Manifest;
    offset : s64 = 0;
   
    manifest.name = deserialize_from_buffer_string(contents.data, *offset);
    
    deserialize_from_buffer(contents.data, *manifest.game_id, *offset, u64);
    deserialize_from_buffer(contents.data, *manifest.tick_rate, *offset, s32);
    deserialize_from_buffer(contents.data, *manifest.duration, *offset, s32);
    deserialize_from_buffer(contents.data, *manifest.player_count, *offset, s32);
    deserialize_from_buffer(contents.data, *manifest.max_players, *offset, s32);
    deserialize_from_buffer(contents.data, *manifest.current_turn, *offset, s32);
    
    array_resize(*manifest.player_list, manifest.max_players);
    for 0..manifest.max_players-1 {
        deserialize_from_buffer(contents.data, *manifest.player_list[it], *offset, u64);
    }
    
    return manifest, true;
}
