Observer_Registry :: struct {
	on_created: 	[MAX_ARCHETYPES][..]Observer_Entry;
	on_destroyed:	[MAX_ARCHETYPES][..]Observer_Entry;
}

Observer_Buffer :: struct {
	created:	[MAX_ARCHETYPES][..]ZEntity;
	destroyed:	[MAX_ARCHETYPES][..]ZEntity;
}

Observer_Entry :: struct {
	priority	: u8;
	proc		: (world: *ZWorld, arch: u16, entity_indices: []ZEntity);
}

array_append :: (array: *[..] $T, to_append: [..]T) { 
    old_count := array.count;
    array_reserve(cast(*Resizable_Array) array, old_count + to_append.count, size_of(T));
    memcpy(array.data + old_count, to_append.data, to_append.count * size_of(T));
    array.count += to_append.count;
}

array_append :: (array: *[..] $T, to_append: []T) {  // Fixed array/slice
    old_count := array.count;
    array_reserve(cast(*Resizable_Array) array, old_count + to_append.count, size_of(T));
    memcpy(array.data + old_count, to_append.data, to_append.count * size_of(T));
    array.count += to_append.count;
}

observe_created_entities :: (world: *ZWorld, archetype: u16, entity: ZEntity) { 
	array_add(*world.observer_buffer.created[archetype], entity);
}
observe_created_entities :: (world: *ZWorld, archetype: u16, entities: [..]ZEntity) { 
	array_append(*world.observer_buffer.created[archetype], entities);
}


Observer_Flags :: enum_flags u8 {
	NONE;
}

Observer :: struct {}

Observer_Ship_Spawn :: struct {
	using #as observer: Observer;

	ENTITY_COMPONENTS 		:: Type.[Position, Rotation, Scale];
	ARCHETYPE_COMPONENTS 	:: Type.[Mesh_Rep];
	TAGS					:: ZTags.SHIP;

	FLAGS					:: Observer_Flags.NONE;
	PRIORITY				:: 0;

	// THIS CODE IS CALLED PER-ENTITY!
	PROC :: (entity_idx: ZEntity, archetype_idx: u16, world: *ZWorld) {
		print("Ship % created!\n", entity_idx);
	}
}
