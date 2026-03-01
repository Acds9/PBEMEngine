MENU_STATE :: enum u8 {
	NONE;
	MAIN;
	NEW_GAME;
	JOIN_GAME;
	SIMULATE_TURN;
	LOAD_REPLAY;
	PAUSE;
	OPTIONS;
}

UI_New_Game_Data :: struct {
	name		: [16]u8;
	tick_rate	: s32 = 60;
	turn_duration : s32 = 15;
	duration	: s32 = 300;
	max_players	: s32 = 2;
}

new_game_data : UI_New_Game_Data;

draw_main_menu :: () {
	using GAME_INSTANCE;
	using ImGui;

	viewport := GetMainViewport();
	center := viewport.WorkPos + viewport.WorkSize * 0.5;
	window_size := ImVec2.{xx (WINDOW_WIDTH/4), xx (WINDOW_HEIGHT/4)};

	SetNextWindowPos(center, .Always, .{0.5, 0.5});  
	SetNextWindowSize(window_size, .Always);
	flags := ImGui.WindowFlags.NoCollapse | .NoMove | .NoResize | .NoTitleBar;  
	if menu_state=={
		case .MAIN; {
			if Begin("Main Menu", null, flags) {
				if Button("New Game") {
					GAME_INSTANCE.menu_state = .NEW_GAME;
				}
				if Button("Join Game") {
					GAME_INSTANCE.menu_state = .JOIN_GAME;
				}
				if Button("Simulate Turn") {
					GAME_INSTANCE.menu_state = .SIMULATE_TURN;
				}
				if Button("Load Replay") {
					GAME_INSTANCE.menu_state = .LOAD_REPLAY;
				}
				if Button("Exit") {
					GAME_INSTANCE.quit = true;
				}
				Text(GAME_VERSION);
				End();
			}
		}
		case .NEW_GAME; {
			if Begin("New Game", null, flags) {
				InputText("Name", new_game_data.name.data, 16);
				SliderInt("Tick Rate", *new_game_data.tick_rate, 30, 360);
				SliderInt("Turn Duration (s)", *new_game_data.turn_duration, 1, 60);
				SliderInt("Duration (s)", *new_game_data.duration, 5, 600);
				SliderInt("Max Players", *new_game_data.max_players, 2, 8);
				if Button("Create") {
					create_game(to_string(new_game_data.name.data), xx new_game_data.tick_rate, xx new_game_data.turn_duration, xx new_game_data.duration, xx new_game_data.max_players);
					GAME_INSTANCE.menu_state = .MAIN;
				}
				if Button("Back") {
					GAME_INSTANCE.menu_state = .MAIN;
				}
				End();
			}
		}
		case .JOIN_GAME; {
			if Begin("Join Game", null, flags) {
				if TreeNode("Games") {
					manifests : [..]Manifest_File;
					read_all_manifests(GAME_FOLDER_PATH, *manifests);
					
					for manifest: manifests {
						name := to_c_string(manifest.name);
						if TreeNode(name) {
							game_id := tprint("Game ID: %", manifest.game_id);
							default_step_resolution := tprint("Default Step Resolution: %", manifest.default_step_resolution);
							time_limit := tprint("Total Steps: %", manifest.total_steps);
							player_count := tprint("Player Count: %", manifest.player_count);
							max_players := tprint("Max Players: %", manifest.max_players);
							current_turn := tprint("Current Turn: %", manifest.current_turn);

							Text(game_id);
							Text(default_step_resolution);
							Text(time_limit);
							Text(player_count);
							Text(max_players);
							Text(current_turn);
							if Button("Join") {
								GAME_INSTANCE.menu_state = .MAIN;
							}
							TreePop();
						}
					}
					TreePop();
				}
				if Button("Back") {
					GAME_INSTANCE.menu_state = .MAIN;
				}
				End();
			}
		}
		case .SIMULATE_TURN; {
			manifests : [..]Manifest_File;
			read_all_manifests(GAME_FOLDER_PATH, *manifests);
			
			for *manifest: manifests {
				Text(manifest.name);
				SameLine();
				if Button("Simulate") {
					print("Sim queued\n");
					queue_simulation(manifest.name);
					break manifest;
				}
			}
		}
		case .LOAD_REPLAY; {
			if Begin("Join Game", null, flags) {
				if TreeNode("Games") {
					manifests : [..]Manifest_File;
					read_all_manifests(GAME_FOLDER_PATH, *manifests);
					
					for manifest: manifests {
						name := to_c_string(manifest.name);
						if Button(name) {
							open_replay(manifest.name);
						}
					}
					TreePop();
				}
				if Button("Back") {
					GAME_INSTANCE.menu_state = .MAIN;
				}
				End();
			}
		}
	}
}
