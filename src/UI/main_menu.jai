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
				SliderInt("Duration (s)", *new_game_data.duration, 5, 600);
				SliderInt("Max Players", *new_game_data.max_players, 2, 8);
				if Button("Create") {
					create_game(to_string(new_game_data.name.data), new_game_data.tick_rate, new_game_data.duration, 8);
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
					manifests := read_all_manifests(GAME_FOLDER_PATH);
					
					for manifest: manifests {
						name := to_c_string(manifest.name);
						if TreeNode(name) {
							game_id := sprint("Game ID: %", manifest.game_id);
							tick_rate := sprint("Tick Rate: %", manifest.tick_rate);
							duration := sprint("Duration: %", manifest.duration);
							player_count := sprint("Player Count: %", manifest.player_count);
							max_players := sprint("Max Players: %", manifest.max_players);
							current_turn := sprint("Current Turn: %", manifest.current_turn);
							defer free(game_id);
							defer free(tick_rate);
							defer free(duration);
							defer free(player_count);
							defer free(max_players);
							defer free(current_turn);

							Text(game_id);
							Text(tick_rate);
							Text(duration);
							Text(player_count);
							Text(max_players);
							Text(current_turn);
							if TreeNode("Player List") {
								for manifest.player_list {
									player_id := sprint("%", it);
									defer free(player_id);
									Text(player_id);
								}
								TreePop();
							}
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
			manifests := read_all_manifests(GAME_FOLDER_PATH);

			for manifest: manifests {
				Text(manifest.name);
				SameLine();
				if Button("Simulate") {
					GAME_INSTANCE.turn_simulation_request = .{true, manifest.name};
					break manifest;
				}
			}
		}
	}
}
