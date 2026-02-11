open_replay :: (game: string) {
	// TODO: for now we just open the snapshot, later we'll need full replay
	GAME_INSTANCE.active_replay_world.name = game;
	initialize_zworld(*GAME_INSTANCE.active_replay_world.world);
	initialize_zscene(*GAME_INSTANCE.active_replay_world.scene, VMA_ALLOCATOR, ZRENDERER.device);
	GAME_INSTANCE.game_world_state = .REPLAY;
	GAME_INSTANCE.menu_state = .NONE;
	snapshot : Timeline_Checkpoint;
	read_turn_game(game, 0, *snapshot);

	offset : s64;
	for 0..snapshot.entity_count-1 {
	//	deserialize_entity(*GAME_INSTANCE.active_replay_world.world, snapshot.entity_data, *offset);
	}
}