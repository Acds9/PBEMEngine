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
	storage := get_archetype_storage(world, Archetype_Ship);
	<<storage = initialize_archetype_storage(Archetype_Ship);
	mesh_rep_component := get_archetype_component(world, Archetype_Ship, Mesh_Rep);
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
	storage := get_archetype_storage(world, Archetype_Point_Light);
	<<storage = initialize_archetype_storage(Archetype_Point_Light);
	storage.initialized = true;
}