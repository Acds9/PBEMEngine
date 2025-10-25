Observer_Ship_Spawn_Event :: (entity_idx: ZEntity, game_state: *Game_State) {
	world := *game_state.world;
	mesh_rep := get_archetype_component(world, get_archetype(entity_idx.archetype), Mesh_Rep);
	mesh, found := table_find(*ZRENDERER.mesh_map, mesh_rep.mesh_name);
	if !found {
		print("WARNING: Could not find % mesh\n", mesh_rep.mesh_name);
	}
	mesh_instance_address := get_entity_component(world, entity_idx, Mesh_Instance_Address);
	mesh_instance_address.mesh_address = add_scene_mesh(*game_state.scene, mesh, Matrix4.{_11=-1, _22=-1, _33=1, _44=1});
}