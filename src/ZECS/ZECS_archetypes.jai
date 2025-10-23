ZTags :: enum_flags u64 {
	SHIP;
	PROJECTILE;
	COMPONENT;
}

Archetype :: struct{
}

Archetype_Ship :: struct{
	using #as archetype: Archetype;

	ENTITY_COMPONENTS    	:: Type.[Position, Rotation, Scale, Mesh_Instance_Address];
    ARCHETYPE_COMPONENTS 	:: Type.[Mesh_Rep];
	TAGS					:: ZTags.SHIP;
	
	CHUNK_SIZE				: u32 : 32;
}; 

init_archetype_Archetype_Ship :: (world: *ZWorld, allocator: *Allocator) {
	storage := get_archetype_storage(world, Archetype_Ship);
	<<storage = initialize_archetype_storage(Archetype_Ship, allocator);
	mesh_rep_component := get_archetype_component(world, Archetype_Ship, Mesh_Rep);
	mesh_rep_component.mesh_name = "ion_frigate";
	storage.initialized = true;
}