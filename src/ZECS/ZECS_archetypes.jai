ZTags :: enum_flags u64 {
	SHIP;
	PROJECTILE;
	COMPONENT;
	LIGHT;
}

Archetype :: struct{
}

Archetype_Ship :: struct{
	using #as archetype: Archetype;

	ENTITY_COMPONENTS    	:: Type.[Position, Rotation, Scale, Thrust, Linear_Velocity, Rotational_Velocity, Mesh_Render_Proxy_EC];
    ARCHETYPE_COMPONENTS 	:: Type.[Mesh_Rep];
	TAGS					:: ZTags.SHIP;
	
	CHUNK_SIZE				: u32 : 32;
}; 

init_archetype_Archetype_Ship :: (world: *ZWorld) {
	archetype_index := get_archetype_index(Archetype_Ship);
	storage := get_archetype_storage(world, archetype_index);
	<<storage = initialize_archetype_storage(archetype_index);
	mesh_rep_component := get_archetype_component(world, archetype_index, Mesh_Rep);
	mesh_rep_component.value = "ion_frigate";
	storage.initialized = true;
}

Archetype_Point_Light :: struct{
	using #as archetype: Archetype;

	ENTITY_COMPONENTS    	:: Type.[Position, Point_Light_Component];
    ARCHETYPE_COMPONENTS 	:: Type.[];
	TAGS					:: ZTags.LIGHT;
	
	CHUNK_SIZE				: u32 : 32;
}; 

init_archetype_Archetype_Point_Light :: (world: *ZWorld) {
	archetype_index := get_archetype_index(Archetype_Point_Light);
	storage := get_archetype_storage(world, archetype_index);
	<<storage = initialize_archetype_storage(archetype_index);
	storage.initialized = true;
}