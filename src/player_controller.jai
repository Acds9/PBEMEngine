Player_Controller :: struct {
	previous_selection	: [..]ZEntity;
	current_selection	: [..]ZEntity;
	selection_dirty		: bool;
}

player_controller_on_selection_change :: (using pc: *Player_Controller) {
	array_reset(*previous_selection);
    array_add(*previous_selection, ..current_selection);
	selection_dirty = true;
}

player_controller_tick :: (using pc: *Player_Controller, game_world: *Game_World) {
	if current_selection.count != 0 {
		entity := current_selection[0];
		
		pos := get_entity_component(*game_world.world, entity, Position);
		debug_draw_mesh(zr = *ZRENDERER, position = pos.value, scale = .{32,32,32});
	}
}

player_controller_set_selection :: (using pc: *Player_Controller, entities: [..]ZEntity) {
	player_controller_on_selection_change(pc);
	current_selection = entities;
}
player_controller_set_selection :: (using pc: *Player_Controller, entity: ZEntity) {
	player_controller_on_selection_change(pc);
	array_reset(*current_selection);
	array_add(*current_selection, entity);
}

player_controller_add_selection :: (using pc: *Player_Controller, entities: [..]ZEntity) {
	player_controller_on_selection_change(pc);
	array_add(*current_selection, ..entities);
}
player_controller_add_selection :: (using pc: *Player_Controller, entity: ZEntity) {
	player_controller_on_selection_change(pc);
	array_add(*current_selection, entity);
}

player_controller_remove_selection :: (using pc: *Player_Controller, entities: [..]ZEntity) {
	player_controller_on_selection_change(pc);
	remove_idx : [..]u32;
	defer array_free(remove_idx);
	for entity: entities {
		for selection: current_selection {
			if selection.index == entity.index && selection.gen == entity.gen || selection.archetype == entity.archetype { // It ain't pretty but for the selection counts it will be fine
				array_add(*remove_idx, xx,no_check it_index);
			}
		} 
	}
	for remove_idx {
		array_unordered_remove_by_index(*current_selection, it);
	}
}

player_controller_remove_selection :: (using pc: *Player_Controller, entity: ZEntity) {
	player_controller_on_selection_change(pc);
	for selection: current_selection {
		if selection.index == entity.index && selection.gen == entity.gen || selection.archetype == entity.archetype { // It ain't pretty but for the selection counts it will be fine
			array_unordered_remove_by_index(*current_selection, xx,no_check it_index);
			break;
		}
	} 
}

player_controller_clear_selection :: (using pc: *Player_Controller) {
	player_controller_on_selection_change(pc);
	array_reset(*current_selection);
}