Observer_Registry :: struct {
	on_created: 	[MAX_ARCHETYPES][..]Observer_Entry;
	on_destroyed:	[MAX_ARCHETYPES][..]Observer_Entry;
}

Observer_Buffer :: struct {
	created:	[MAX_ARCHETYPES][..]ZEntity;
	destroyed:	[MAX_ARCHETYPES][..]ZEntity;

	reset :: (using self: *Observer_Buffer) {
		for *created array_reset(it);
		for *destroyed array_reset(it);
	}
}

Observer_Entry :: struct {
	priority	: u8;
	proc		: (game_state: *Game_State, entity_indices: []ZEntity);
}