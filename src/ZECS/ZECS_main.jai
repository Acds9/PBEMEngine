#import "Basic";
fp :: #import "Flat_Pool";

DEFAULT_ENTITY_CHUNK_SIZE 	:: 64;
HOT_ARCHETYPE_CHUNK_SIZE 	:: 256;
COLD_ARCHETYPE_CHUNK_SIZE 	:: 32;

DEFAULT_POOL_SIZE 			:: 40 * 1024;  // 40KB per archetype pool
MAX_ENTITIES_PER_ARCHETYPE	:: 2048;
CACHE_LINE_SIZE				: u32 : 64;


ZEntity :: struct
{
	index 		: u32;
	gen			: u16;
	archetype	: u16;
}

entity_is_valid :: (e: *ZEntity) -> bool {
	return e.index != 0;
}

entity_is_alive :: (world: *ZWorld, entity: ZEntity) -> bool {
	arch_storage := *world.world_archetypes[entity.archetype];

	return bit_test(arch_storage.alive_mask, entity.index);
}

entity_is_alive :: (entity: ZEntity, storage: *Archetype_Storage ) -> bool {
	return bit_test(storage.alive_mask, entity.index);
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


ZWorld :: struct {
	world_archetypes 	: [MAX_ARCHETYPES]Archetype_Storage;
	world_entities 		: [..]ZEntity;

	observer_registry	: Observer_Registry;
	observer_buffer		: Observer_Buffer;

	// Memory
	world_pool			: fp.Flat_Pool;

}

create_zworld :: (pool_size: s64 = DEFAULT_POOL_SIZE) -> *ZWorld {
	world := New(ZWorld);

	fp.init(*world.world_pool, pool_size);
	allocator := Allocator.{fp.flat_pool_allocator_proc, *world.world_pool};

	world.world_entities.allocator = allocator;

	return world;
}

reset_world :: (world: *ZWorld) {
    fp.reset(*world.world_pool);
    // All allocations are now invalid, arrays need to be reinitialized next turn
}

init_archetype :: (world: *ZWorld, archetype: Type) {
    allocator := Allocator.{fp.flat_pool_allocator_proc, *world.world_pool};
	storage := get_archetype_storage(world, archetype);
	<<storage = initialize_archetype_storage(archetype, allocator);
	
	storage.initialized = true;
}

get_archetype_storage :: (world: *ZWorld, archetype: Type) -> *Archetype_Storage {
	return *world.world_archetypes[get_arch_index(archetype)];
}

tick_world :: (world: *ZWorld, delta_time: float64) {
	flush_observers(world);
}

observe_created_entities :: (world: *ZWorld, archetype: u16, entity: ZEntity) { 
	array_add(*world.observer_buffer.created[archetype], entity);
}
observe_created_entities :: (world: *ZWorld, archetype: u16, entities: [..]ZEntity) { 
	array_append(*world.observer_buffer.created[archetype], entities);
}

flush_observers :: (world: *ZWorld) {
	for *world.observer_buffer.created {
		if it.count == 0 continue;
		entities := it;
		
		arch_idx := cast,no_check(u16)it_index;
		bound_observers := world.observer_registry.on_created[arch_idx];
		for bound_observers {
			it.proc(world, arch_idx, <<entities);
		}
	}
	for *world.observer_buffer.destroyed {
		if it.count == 0 continue;
		entities := it;
		
		arch_idx := cast,no_check(u16)it_index;
		bound_observers := world.observer_registry.on_destroyed[arch_idx];
		for bound_observers {
			it.proc(world, arch_idx, <<entities);
		}
	}
	world.observer_buffer.reset(*world.observer_buffer);
}

// Entities

// idx and gen can be used to force a specific index and gen onto the entity for deserialization
create_entity :: (world: *ZWorld, arch: Type, idx : u32 = 0, gen : u16 = 0) -> ZEntity {
	arch_storage := get_archetype_storage(world, arch);
	if !arch_storage.initialized {
		init_archetype(world, arch);
		arch_storage = get_archetype_storage(world, arch); // Re-get, may be invalid
	}

	if (arch_storage.num_entities - arch_storage.free_indices.count) >= MAX_ENTITIES_PER_ARCHETYPE {
		assert(false, "ERROR: Attempted to spawn more entities than MAX_ENTITIES_PER_ARCHETYPE allows\n");
		return .{};
	}
	entity_idx : u32;
	entity_gen : u16;

	if(idx != 0) {
		// Assumes there are already allocated slots
		entity_idx = idx;
		entity_gen = gen;
	} else {
		if arch_storage.free_indices {
			entity_idx = pop(*arch_storage.free_indices);
            entity_gen = arch_storage.generations[entity_idx];
		} else {
			entity_idx = arch_storage.num_entities;
			arch_storage.num_entities += 1; 

			if entity_idx >= arch_storage.generations.count {
           		array_resize(*arch_storage.generations, entity_idx + arch_storage.chunk_size);
        	}
		}	
	}

	bit_set(*arch_storage.alive_mask, entity_idx);

	// Ensure component storage is allocated
    ensure_component_capacity(world, arch_storage, entity_idx + 1);

	init_entity_components(arch, arch_storage, entity_idx);

	entity := ZEntity.{
		index = entity_idx,
		gen = entity_gen,
		archetype = get_arch_index(arch)
	};

	array_add(*world.world_entities, entity);
	observe_created_entities(world, get_arch_index(arch), entity);
	return entity;
}

create_entity_batch :: (world: *ZWorld, $arch_type: Type, count: u32) -> []ZEntity {
    if count == 0 return .[];

    arch_idx := get_arch_index(arch_type);
    arch_storage := *world.world_archetypes[arch_idx];
    
    // Initialize archetype if needed
    if arch_storage.entity_component_mask.data[0] == 0 {
        init_archetype(world, arch_type);
        arch_storage = *world.world_archetypes[arch_idx];
    }

	if (arch_storage.num_entities - arch_storage.free_indices.count + count) >= MAX_ENTITIES_PER_ARCHETYPE {
		assert(false, "ERROR: Attempted to spawn more entities than MAX_ENTITIES_PER_ARCHETYPE allows\n");
		return .[.{}];
	}
    
    entities: [..]ZEntity;
    array_reserve(*entities, count);
    
    // Pre-allocate all storage at once
    start_idx := arch_storage.num_entities;
    needed_capacity := start_idx + count;
    
    // Handle free list first
    while arch_storage.free_indices && entities.count < count {
        entity_idx := pop(*arch_storage.free_indices);
        entity_gen := arch_storage.generations[entity_idx];
        
        entity := ZEntity.{
            index = entity_idx,
            gen = entity_gen,
            archetype = cast(u16)arch_idx
        };
        
		bit_set(*arch_storage.alive_mask, entity_idx);
        array_add(*entities, entity);
        init_entity_components(arch_type, arch_storage, entity_idx);
    }
    
    // Allocate new entities for the rest
    remaining := count - cast(u32)entities.count;
    if remaining > 0 {
        // Ensure capacity for all new entities at once
        ensure_component_capacity(world, arch_storage, arch_storage.num_entities + remaining);
        
        if arch_storage.generations.count < arch_storage.num_entities + remaining {
            array_resize(*arch_storage.generations, arch_storage.num_entities + remaining);
        }
        
        // Create all remaining entities
        for i: 0..remaining-1 {
            entity_idx := arch_storage.num_entities;
            arch_storage.num_entities += 1;
            
            entity := ZEntity.{
                index = entity_idx,
                gen = arch_storage.generations[entity_idx],
                archetype = cast(u16)arch_idx
            };
            
			bit_set(*arch_storage.alive_mask, entity_idx);
            array_add(*entities, entity);
            init_entity_components(arch_type, arch_storage, entity_idx);
        }
    }
    
    // Add all to world entities
    array_reserve(*world.world_entities, world.world_entities.count + count);
    for entities {
        array_add(*world.world_entities, it);
    }
    
	observe_created_entities(world, get_arch_index(arch_type), entities);
    return entities;
}

destroy_entity :: (world: *ZWorld, entity: ZEntity) {
	arch_storage := *world.world_archetypes[entity.archetype];

	if !entity_is_alive(world, entity) return;

	arch_storage.generations[entity.index] += 1;

	bit_clear(*arch_storage.alive_mask, entity.index);

	array_add(*arch_storage.free_indices, entity.index);
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
	return cast(*T) *storage.entity_components[get_archetype_component_index(get_index_arch(archetype), T)].data;
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

// TODO: move to its own file

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
