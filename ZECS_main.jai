#import "Basic";
#import "Flat_Pool";

CACHE_LINE_SIZE				: u32 : 64;
MAX_ARCHETYPES          	::  128;

DEFAULT_ENTITY_CHUNK_SIZE 	:: 64;
HOT_ARCHETYPE_CHUNK_SIZE 	:: 256;
COLD_ARCHETYPE_CHUNK_SIZE 	:: 32;
DEFAULT_POOL_SIZE 			:: 40 * 1024;  // 40KB per archetype pool

ZEntity :: struct
{
	index 		: u32;
	gen			: u16;
	archetype	: u16;
}

entity_is_valid :: (e: *ZEntity) -> bool {
	return e.index != 0;
}

entity_to_u64 :: (e: *ZEntity) -> u64 {
	return cast, no_check(u64)e.archetype << 48 | cast, no_check(u64)e.gen << 32 | cast, no_check(u64)e.index;
}

u64_to_entity :: (n: u64) -> ZEntity {
	return ZEntity.{
		index = cast(u32)(n & 0xFFFFFFFF),
		gen = cast(u16)((n >> 32) & 0xFFFF),
		archetype = cast(u16)((n >> 48) & 0xFFFF)
	};
}

entity_equals :: (lhs: *ZEntity, rhs: *ZEntity)->bool {
	return lhs.archetype == rhs.archetype && lhs.index == rhs.index && lhs.gen == rhs.gen;
}

// Components

Entity_Component_Storage :: struct {
	type			: Type;
	data			: [..]u8;		// Raw data, this is the array where all the entity entity_components are stored linearly
	stride			: u32;			// How many entity_components we have space allocated for
	capacity		: u32;			// How many components allocated
}

get_storage_capacity :: (storage: *Entity_Component_Storage) -> u32 {
	return cast(u32)(storage.data.count/storage.stride);
}

// Archetypes

Archetype_Storage :: struct
{
	entity_components 		: [MAX_ENTITY_COMPONENTS]Entity_Component_Storage;
	entity_component_mask 	: Bit_Field(MAX_ENTITY_COMPONENTS);
	
	// Entities
	entity_count			: u32;
	free_indices			: [..]u32; // Free-list for indices
	generations				: [..]u16; // Generations for each index

	// Memory
	pool					: Flat_Pool;

	// Autogenerate these from archetype data later
	chunk_size				: u32;
	is_hot					: bool;
}

get_entity_component :: (world: *ZWorld, entity: ZEntity, $T: Type) -> *T {
	as := *world.world_archetypes[entity.archetype];
	
	comp_idx := get_entity_component_index(T);
	assert(comp_idx > 0);
    
    assert(bit_test(as.entity_component_mask, comp_idx));
	
	comp_storage := *as.entity_components[comp_idx];

	offset := entity.index * comp_storage.stride;
	return cast(*T) *comp_storage.data[offset];
}

// World

ZWorld :: struct
{
	world_archetypes 	: [MAX_ARCHETYPES]Archetype_Storage;
	world_entities 		: [..]ZEntity;
}

init_archetype :: (world: *ZWorld, archetype: Archetype) {
	
	arch_idx : u16;// = get_arch_index(type_of(archetype)); 			

	arch := *world.world_archetypes[arch_idx];
	//arch.entity_component_mask = make_component_mask(archetype.entity_components);						
	arch.chunk_size = archetype.chunk_size; 			
	
	for arch.entity_component_mask {
        storage := *arch.entity_components[it];
        storage.type = get_entity_component_type(it);
        storage.stride = get_entity_component_size(storage.type);

		// Align stride to cache line for components >= 32 bytes
        if storage.stride >= 32 {
            storage.stride = (storage.stride + CACHE_LINE_SIZE - 1) & ~(CACHE_LINE_SIZE - 1);}
    };
   
}

make_component_mask :: (components: []Type) -> Bit_Field(MAX_ENTITY_COMPONENTS) {
	bit_field : Bit_Field(MAX_ENTITY_COMPONENTS) = .{};
	for components {
		idx := get_entity_component_index(it);

		bit_set(*bit_field, idx);
	}

	return bit_field;
}