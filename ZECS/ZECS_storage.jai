#import "Basic";

DEFAULT_ENTITY_CHUNK_SIZE 	:: 64;
HOT_ARCHETYPE_CHUNK_SIZE 	:: 256;
COLD_ARCHETYPE_CHUNK_SIZE 	:: 32;

DEFAULT_POOL_SIZE 			:: 40 * 1024;  // 40KB per archetype pool
MAX_ENTITIES_PER_ARCHETYPE	:: 2048;


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

// Components

Entity_Component_Storage :: struct {
	type			: Type;
	data			: [..]u8;		// Raw data, this is the array where all the entity entity_components are stored linearly
	stride			: u32;			// Size of one component in bytes
}

get_storage_capacity :: (storage: *Entity_Component_Storage) -> u32 {
	return cast(u32)(storage.data.count/storage.stride);
}

array_view :: ($T: Type, storage: *Entity_Component_Storage, count: u32) -> []T {
    result: []T = ---;
    result.data = cast,no_check(*T) storage.data.data;
    result.count = count;
    return result;
}

array_view_dynamic :: (arr: [..]$T, count: int) -> []T {
	result: []T = ---;
    result.data = arr.data;
    result.count = count;
    return result;
}

Archetype_Component_Storage :: struct {
	type			: Type;
	data			: Any;	// Stores 1 component, no more
}

// Archetypes
Arch_Storage_Initializer :: #type (alloc: Allocator) -> Archetype_Storage;
Archetype_Storage :: struct {
	initialized					: bool;
	entity_components 			: [..]Entity_Component_Storage;
	entity_component_mask 		: Bit_Field(MAX_ENTITY_COMPONENTS);
	
	archetype_components		: [..]Archetype_Component_Storage;
	archetype_component_mask	: Bit_Field(MAX_ARCH_COMPONENTS);

	tags						: ZTags;
	
	// Entities
	num_entities			: u32;
	free_indices			: [..]u32; // Free-list for indices
	generations				: [..]u16; // Generations for each index
	alive_mask				: Bit_Field(MAX_ENTITIES_PER_ARCHETYPE); //TODO: this should start small and be built out as needed, even 8192 entities will be a full kb of data

	// Autogenerate this from archetype data later
	chunk_size				: u32 = DEFAULT_ENTITY_CHUNK_SIZE;
}

get_entity_component_storage :: (world: *ZWorld, archetype_idx: u16, $T: Type) -> *Entity_Component_Storage {
	return get_e_c_storage_ptr(world, archetype_idx, T);
}

// TODO: add some bool returns to these
get_entity_component :: (world: *ZWorld, entity: ZEntity, $T: Type) -> *T {
	storage := get_e_c_storage_ptr(world, get_index_arch(entity.archetype), T);
	offset := entity.index * storage.stride;
	return cast(*T) *storage.data[offset];
}

get_entity_component :: (storage: *Entity_Component_Storage, idx: u32,  $T: Type) -> *T {
	offset := idx * storage.stride;
	return cast(*T) *storage.data[offset];
} 

get_archetype_component :: (world: *ZWorld, archetype: u16, $T: Type) -> *T {
	storage := *world.world_archetypes[archetype];
	return cast(*T) *storage.entity_components[get_archetype_component_index(archetype, T)].data;
}

ensure_component_capacity :: (world: *ZWorld, storage: *Archetype_Storage, needed_count: u32) {
	
	allocator := Allocator.{fp.flat_pool_allocator_proc, *world.world_pool};
    
	for *comp_storage: storage.entity_components {
		comp_storage.data.allocator = allocator;
		needed_bytes := needed_count * comp_storage.stride;
		if comp_storage.data.count < needed_bytes {
			array_resize(*comp_storage.data, needed_bytes);
		}
		// This might "leak" the old allocation in the pool, but who cares?
		// We reset the entire pool between turns anyway, but worth keeping in mind
	}
    
}