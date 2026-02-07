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
	game_folder := sprint("%/%", GAME_FOLDER_NAME, game);
	defer free(game_folder);
	return file_exists(game_folder);
}

get_game_directory :: (game: string) -> string {
	if !does_game_exist(game) {
		return "";
	}
	return tprint("%/%", GAME_FOLDER_NAME, game);
}

get_order_directory :: (game: string) -> string #must {
	if !does_game_exist(game) {
		return "";
	}
	return tprint("%/%/%", GAME_FOLDER_NAME, game, ORDER_FOLDER_NAME);
}

get_turn_directory :: (game: string) -> string {
	if !does_game_exist(game) {
		return "";
	}
	return tprint("%/%/%", GAME_FOLDER_NAME, game, TURN_FOLDER_NAME);
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

// MANIFEST

read_manifest_name :: (game: string, manifest: *Game_Manifest) -> bool {
	manifest_paths := file_list_ext(GAME_FOLDER_PATH, ".mft", true);
	for path: manifest_paths {
		_, filename, _, _ := path_decomp(path);
		if equal(game, filename) {
			return read_manifest(path, manifest);
		}
	}
	return false;
}

read_all_manifests :: (folder: string, manifests: *[..]Game_Manifest) { 
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

read_manifest :: (path: string, manifest: *Game_Manifest) -> bool {
	contents, success := read_entire_file(path);
    if !success {
		return false;
	}
    <<manifest = deserialize_game_manifest(xx contents);
    return true;
}

// TURN

read_turn :: (path: string, turn: u32, dest: *Snapshot) {
	contents, success := read_entire_file(path);
	offset : s64;
   	deserialize_snapshot(dest, xx contents, *offset);
}

read_turn_game :: (game: string, turn: u32, dest: *Snapshot) {
	path := tprint("%/%_%.%", get_turn_directory(game), game, turn, TURN_EXT);
	read_turn(path, turn, dest);
};

// ORDERS

read_all_orders :: (folder: string, orders: *[..]Turn_Orders) { 
	order_paths := file_list_ext(folder, ".order", true);
	defer free(order_paths.data);
	
	if !order_paths.count {
		return;
	}
	array_resize(orders, order_paths.count);
	read_success : bool;
	for file: order_paths {
		read_success = read_orders(file, *(<<orders)[it_index]);
		if !read_success {
			print("WARNING: Could not read order file %\n", file);
		}
	}
}

read_orders :: (path: string, orders: *Turn_Orders) -> bool {
	print("%\n", path);
	contents, success := read_entire_file(path);
	
    if !success {
		return false;
	}
    <<orders = deserialize_orders(xx contents);
    return true;
}