Observer_Ship_Spawn_Event :: (entity_idx: ZEntity, game_state: *Game_State) {
	world := *game_state.world;
	mesh_rep := get_archetype_component(world, get_archetype(entity_idx.archetype), Mesh_Rep);
	mesh, found := table_find(*ZRENDERER.mesh_map, mesh_rep.mesh_name);
	if !found {
		print("WARNING: Could not find % mesh\n", mesh_rep.mesh_name);
	}
	mesh_instance_address := get_entity_component(world, entity_idx, Mesh_Render_Proxy_EC);
	mesh_instance_address.idx_mesh_instance = add_scene_mesh(*game_state.scene, mesh, Matrix4.{_11=-1, _22=-1, _33=1, _44=1});
	location_address := get_entity_component(world, entity_idx, Position);
	random_pos : Vector3 = .{0, cast,no_check(float)entity_idx.index*70, 0};
	location_address.pos = random_pos;
	//print("%\n", random_pos);
}

Observer_Point_Light_Spawn_Event :: (entity_idx: ZEntity, game_state: *Game_State) {
	world := *game_state.world;
	scene := *game_state.scene;

	position := get_entity_component(world, entity_idx, Position);
	point_light := get_entity_component(world, entity_idx, Point_Light_Component);
	light : Point_Light;
    light.position = position.pos;
    light.radius = point_light.radius;
    light.color = vec4_to_color(*point_light.color);
    point_light.light_address = add_scene_point_light(scene, light);
}