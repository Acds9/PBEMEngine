Observer_Ship_Spawn_Event :: (entity_idx: ZEntity, game_world: *Game_World) {
	world := *game_world.world;
	mesh_rep := get_archetype_component(world, get_archetype(entity_idx.archetype), Mesh_Rep);
	mesh, found := table_find(*ZRENDERER.mesh_map, mesh_rep.value);
	if !found {
		print("WARNING: Could not find % mesh\n", mesh_rep.value);
	}
	
	mesh_instance_address := get_entity_component(world, entity_idx, Mesh_Render_Proxy_EC);
	add_scene_mesh(*game_world.scene, mesh, Matrix4.{_11=-1, _22=-1, _33=1, _44=1}, *mesh_instance_address.value);
	location_address := get_entity_component(world, entity_idx, Position);
	random_pos : Vector3 = .{0, cast,no_check(float)entity_idx.index*140, 0};
	location_address.value = random_pos;
}

Observer_Point_Light_Spawn_Event :: (entity_idx: ZEntity, game_world: *Game_World) {
	world := *game_world.world;
	scene := *game_world.scene;

	position := get_entity_component(world, entity_idx, Position);
	point_light := get_entity_component(world, entity_idx, Point_Light_Component);
	light : Point_Light;
    light.position = position.value;
    light.radius = point_light.radius;
    light.color = vec4_to_color(*point_light.color);
   	add_scene_point_light(scene, light, *point_light.light_address);
}