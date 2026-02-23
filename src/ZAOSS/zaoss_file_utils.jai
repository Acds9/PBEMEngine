GAME_FOLDER_NAME :: "games";
TURN_FOLDER_NAME :: "turns";
ORDER_FOLDER_NAME :: "orders";

GAME_FOLDER_PATH :: #run -> string {
	cwd := get_working_directory();
	return sprint("%/%", cwd, GAME_FOLDER_NAME);
}

MANIFEST_EXT 	:: "mft";
GAME_EXT		:: "game";
TURN_EXT		:: "turn";
ORDER_EXT		:: "order";

// DIRECTORY

does_game_exist :: (game: string) -> bool {
	if !game {
		return false;
	}
	game_folder := sprint("%/%", GAME_FOLDER_PATH, game);
	defer free(game_folder);
	return file_exists(game_folder);
}

get_game_directory :: (game: string) -> string {
	if !does_game_exist(game) {
		return "";
	}
	return tprint("%/%", GAME_FOLDER_PATH, game);
}

get_order_directory :: (game: string) -> string #must {
	if !does_game_exist(game) {
		return "";
	}
	return tprint("%/%/%", GAME_FOLDER_PATH, game, ORDER_FOLDER_NAME);
}

get_turn_directory :: (game: string) -> string {
	if !does_game_exist(game) {
		return "";
	}
	return tprint("%/%/%", GAME_FOLDER_PATH, game, TURN_FOLDER_NAME);
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

// FILE

get_manifest_file_path :: (game: string) -> string {
	return tprint("%/%.%", get_game_directory(game), game, MANIFEST_EXT);
}

get_game_file_path :: (game: string) -> string {
	return tprint("%/%.%", get_game_directory(game), game, GAME_EXT);
}

get_turn_file_path :: (game: string, turn: u32) -> string {
	return tprint("%/%_%.%", get_turn_directory(game), game, turn, TURN_EXT);
}

get_order_file_path :: (game: string, turn: u32) -> string {
	return tprint("%/%_%.%", get_order_directory(game), game, turn, ORDER_EXT);
}

// MANIFEST

read_manifest_name :: (game: string, manifest: *Manifest_File) -> bool {
	manifest_paths := file_list_ext(GAME_FOLDER_PATH, ".mft", true);
	for path: manifest_paths {
		_, filename, _, _ := path_decomp(path);
		if equal(game, filename) {
			return read_manifest(path, manifest);
		}
	}
	return false;
}

read_all_manifests :: (folder: string, manifests: *[..]Manifest_File) { 
	manifest_paths := file_list_ext(folder, ".mft", true);
	defer free(manifest_paths.data);
	
	if !manifest_paths.count {
		return;
	}
	array_resize(manifests, manifest_paths.count);
	read_success : bool;
	for file: manifest_paths {
		read_success = read_manifest(file, *(<<manifests)[it_index]);
		if !read_success {
			print("WARNING: Could not read manifest %\n", file);
		}
	}
}

read_manifest :: (path: string, manifest: *Manifest_File) -> bool {
	contents, success := read_entire_file(path);
    if !success {
		return false;
	}
	offset : s64;
    deserialize(manifest, xx contents, *offset);
    return true;
}
