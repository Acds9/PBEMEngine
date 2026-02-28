Observer_Registry :: struct {
	on_created: 	[MAX_ARCHETYPES][..]Observer_Entry;
	on_destroyed:	[MAX_ARCHETYPES][..]Observer_Entry;
}

deinitialize :: (using observer_registry: *Observer_Registry) {
	for on_created {
		array_free(it);
	}
	for on_destroyed {
		array_free(it);
	}
}

Observer_Buffer :: struct {
	created:	[MAX_ARCHETYPES][..]ZEntity;
	destroyed:	[MAX_ARCHETYPES][..]ZEntity;

	reset :: (using self: *Observer_Buffer) {
		for *created array_reset(it);
		for *destroyed array_reset(it);
	}
}

deinitialize :: (using observer_buffer: *Observer_Buffer) {
	for created {
		array_free(it);
	}
	for destroyed {
		array_free(it);
	}
}

Observer_Entry :: struct {
	priority	: u8;
	proc		: (game_world: *Game_World, entity_indices: []ZEntity);
}

