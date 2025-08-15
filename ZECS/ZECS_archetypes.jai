ZTags :: enum_flags u64 {
	SHIP;
	PROJECTILE;
	COMPONENT;
}

initialize_archetype_storage :: (archetype: u16, alloc: Allocator) -> Archetype_Storage {
	storage: Archetype_Storage;
	data := get_archetype_data(archetype);

	storage.entity_components.allocator = alloc;
	storage.archetype_components.allocator = alloc;
	storage.free_indices.allocator = alloc;
	storage.generations.allocator = alloc;

	storage.entity_component_mask = data.entity_component_mask;
	storage.archetype_component_mask = data.archetype_component_mask;

	array_resize(*storage.entity_components, data.entity_components.count);
	array_resize(*storage.archetype_components, data.entity_components.count);

	for data.entity_components {
		storage.entity_components[it_index].type = it;
		storage.entity_components[it_index].stride = get_entity_component_size(it);
	}

	storage.archetype_components[0].type = Mesh_Rep;
	storage.archetype_components[0].data = Any.{type = type_info(Mesh_Rep), value_pointer = cast(*void)(*Archetype_Ship.DEFAULT_Mesh_Rep)}; // TODO: Fix this, need to pass the proper initializer func I think
	storage.tags = data.tags;
	storage.chunk_size = data.chunk_size;
	return storage;
}

initialize_archetype_storage :: (archetype: Type, alloc: Allocator) -> Archetype_Storage {
	return initialize_archetype_storage(get_arch_index(archetype), alloc);
}

Archetype :: struct{
}

Archetype_Ship :: struct{
	using #as archetype: Archetype;

	ENTITY_COMPONENTS    	:: Type.[Position, Rotation, Scale];
    ARCHETYPE_COMPONENTS 	:: Type.[Mesh_Rep];
	TAGS					:: ZTags.SHIP;
	// TODO: Why not just define an initializer function instead that sets the data when an archetype is instantiated?
	DEFAULT_Mesh_Rep		:: Mesh_Rep.{mesh_name = "Test"};  // Could put some sort of insert macro that adds DEFAULT_ automatically to tagged vars? 

	CHUNK_SIZE				: u32 : 32;
}; 