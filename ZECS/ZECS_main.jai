#import "Basic";
fp :: #import "Flat_Pool"(DEFAULT_VIRTUAL_MEMORY_RESERVE = DEFAULT_POOL_SIZE);

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

entity_alive :: (world: *ZWorld, entity: ZEntity) -> bool {
	arch_storage := *world.world_archetypes[entity.archetype];

	return arch_storage.generations[entity.index] == entity.gen;
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
	stride			: u32;			// Size of one component in bytes
}

get_storage_capacity :: (storage: *Entity_Component_Storage) -> u32 {
	return cast(u32)(storage.data.count/storage.stride);
}

Archetype_Component_Storage :: struct {
	type			: Type;
	data			: [..]u8;	// Stores 1 component, no more
}

// Archetypes

Archetype_Storage :: struct {
	entity_components 			: [..]Entity_Component_Storage;
	entity_component_mask 		: Bit_Field(MAX_ENTITY_COMPONENTS);
/*
	archetype_components		: [..]Archetype_Component_Storage;
	archetype_component_mask	: Bit_Field(MAX_ARCH_COMPONENTS);

	tags						: Bit_Field(MAX_TAGS);
*/	
	// Entities
	num_entities			: u32;
	free_indices			: [..]u32; // Free-list for indices
	generations				: [..]u16; // Generations for each index

	// Autogenerate this from archetype data later
	chunk_size				: u32;
}

// Unsafe, assumes component exists
get_entity_component :: (world: *ZWorld, entity: ZEntity, $T: Type) -> *T {
	comp_storage := get_e_c_storage_ptr(world, entity.archetype, T);
	offset := entity.index * comp_storage.stride;
	return cast(*T) *comp_storage.data[offset];
}

// World

ZWorld :: struct {
	world_archetypes 	: [MAX_ARCHETYPES]Archetype_Storage;
	world_entities 		: [..]ZEntity;

	// Memory
	world_pool			: fp.Flat_Pool;
}

create_zworld :: (pool_size: s64 = DEFAULT_POOL_SIZE) -> *ZWorld {
	world := New(ZWorld);

	fp.init(*world.world_pool, pool_size);
	world.world_entities.allocator = Allocator.{fp.flat_pool_allocator_proc, *world.world_pool};

	return world;
}

reset_world :: (world: *ZWorld) {
    fp.reset(*world.world_pool);
    // All allocations are now invalid, arrays need to be reinitialized next turn
}

init_archetype :: (world: *ZWorld, archetype: Archetype) {
	
	arch_idx : u16 = get_arch_index(type_of(archetype)); 			

	arch := *world.world_archetypes[arch_idx];
	arch.entity_component_mask = make_component_mask(archetype.entity_components);						
	arch.chunk_size = archetype.chunk_size; 
	
	allocator := Allocator.{flat_pool_allocator_proc, *world.world_pool};
    arch.entity_components.allocator = allocator;
    array_resize(*arch.entity_components, archetype.entity_components.count);
	
	for arch.entity_component_mask {
        storage := *arch.entity_components[it];
        storage.type = get_entity_component_type(it);
        storage.stride = get_entity_component_size(storage.type);
		storage.data.allocator = allocator;

		// Align stride to cache line for components >= 32 bytes
        if storage.stride >= 32 {
            storage.stride = (storage.stride + CACHE_LINE_SIZE - 1) & ~(CACHE_LINE_SIZE - 1);
		}
    };
}

// TODO: 
// 1) Add archetype component logic
// 2) try to get an entity spawned and rendering

make_component_mask :: (components: []Type) -> Bit_Field(MAX_ENTITY_COMPONENTS) {
	bit_field : Bit_Field(MAX_ENTITY_COMPONENTS) = .{};
	for components {
		idx := get_entity_component_index(it);

		bit_set(*bit_field, idx);
	}

	return bit_field;
}

// Entities

// idx and gen can be used to force a specific index and gen onto the entity for deserialization
create_entity :: (world: *ZWorld, arch: Type, idx : u32 = 0, gen : u16 = 0) -> ZEntity {
	arch_idx := get_arch_index(arch);

	arch_storage := *world.world_archetypes[arch_idx];
	entity_idx : u32;
	entity_gen : u16;
	if(idx != 0) {
		// Assumes there are already allocated slots
		entity_idx = idx;
		entity_gen = gen;
	} else {
		if arch_storage.free_indices {
			entity_idx = pop(*arch_storage.free_indices);
		} else {
			entity_idx = arch_storage.num_entities;
			arch_storage.num_entities += 1; 

			if entity_idx >= arch_storage.generations.count {
           		array_resize(*arch_storage.generations, entity_idx + arch_storage.chunk_size);
        	}
		}	
	}

	// Ensure component storage is allocated
    ensure_component_capacity(world, arch_storage, entity_idx + 1);

	entity := ZEntity.{
		index = entity_idx,
		gen = arch_storage.generations[entity_idx],
		archetype = cast(u16)arch_idx
	};

	array_add(*world.world_entities, entity);
	return entity;
}

destroy_entity :: (world: *ZWorld, entity: ZEntity) {
	arch_storage := *world.world_archetypes[entity.archetype];

	if !entity_alive(world, entity) return;

	arch_storage.generations[entity.index] += 1;

	array_add(*arch_storage.free_indices, entity.index);
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