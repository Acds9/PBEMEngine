#import "Basic";
fp :: #import "Flat_Pool";

DEFAULT_ENTITY_CHUNK_SIZE 	:: 64;

MAX_ENTITIES_PER_ARCHETYPE	:: 2048;

ZEntity :: struct {
	index 		: u32;
	gen			: u16;
	archetype	: u16;
}

entity_is_alive :: (world: *ZWorld, entity: ZEntity) -> bool {
	arch_storage := *world.world_archetypes[entity.archetype];

	return bit_test(arch_storage.alive_mask, entity.index);
}

entity_is_alive :: (entity_idx: u32, storage: *Archetype_Storage ) -> bool {
	return bit_test(storage.alive_mask, entity_idx);
}

ZWorld :: struct {
	world_archetypes 	: [MAX_ARCHETYPES]Archetype_Storage;
	world_entities 		: [..]ZEntity;

	observer_registry	: Observer_Registry;
	observer_buffer		: Observer_Buffer;
}

init_zworld :: (world: *ZWorld) {
	initialize_archetypes(world);
    register_observers(world);
}

reset_world :: (world: *ZWorld) {
   
}

init_archetype :: (world: *ZWorld, archetype: Type) {
	storage := get_archetype_storage(world, archetype);
	<<storage = initialize_archetype_storage(archetype);
	
	storage.initialized = true;
}

get_archetype_storage :: (world: *ZWorld, archetype: Type) -> *Archetype_Storage {
	return *world.world_archetypes[get_archetype_storage_index(archetype)];
}

tick_world :: (world: *ZWorld, delta_time: float32) {
	flush_observers(world);
}

observer_add_created_entities :: (world: *ZWorld, archetype: u16, entity: ZEntity) { 
	array_add(*world.observer_buffer.created[archetype], entity);
}
observer_add_created_entities :: (world: *ZWorld, archetype: u16, entities: [..]ZEntity) { 
	array_add(*world.observer_buffer.created[archetype], ..entities);
}

flush_observers :: (world: *ZWorld) {
	for *world.observer_buffer.created {
		if it.count == 0 continue;
		entities := it;
		
		arch_idx := cast,no_check(u16)it_index;
		bound_observers := world.observer_registry.on_created[arch_idx];
		for bound_observers {
			it.proc(*GAME_INSTANCE, <<entities);
		}
		barrier_wait(context.lane_barrier);
	}
	for *world.observer_buffer.destroyed {
		if it.count == 0 continue;
		entities := it;
		
		arch_idx := cast,no_check(u16)it_index;
		bound_observers := world.observer_registry.on_destroyed[arch_idx];
		for bound_observers {
			it.proc(*GAME_INSTANCE, <<entities);
		}
		barrier_wait(context.lane_barrier);
	}
	barrier_wait(context.lane_barrier); // Don't want thread 0 to reset before all threads are done 
	if context.thread_index == 0 {
		world.observer_buffer.reset(*world.observer_buffer);
	}
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
		archetype = get_archetype_storage_index(arch)
	};

	array_add(*world.world_entities, entity);
	observer_add_created_entities(world, get_archetype_storage_index(arch), entity);
	return entity;
}

create_entity_batch :: (world: *ZWorld, $arch_type: Type, count: u32) -> []ZEntity {
    if count == 0 return .[];

    arch_idx := get_archetype_storage_index(arch_type);
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
	defer array_free(entities);
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
    
	observer_add_created_entities(world, get_archetype_storage_index(arch_type), entities);
    return entities;
}

destroy_entity :: (world: *ZWorld, entity: ZEntity) {
	arch_storage := *world.world_archetypes[entity.archetype];

	if !entity_is_alive(world, entity) return;

	arch_storage.generations[entity.index] += 1;

	bit_clear(*arch_storage.alive_mask, entity.index);

	array_add(*arch_storage.free_indices, entity.index);
}

// Allocator has to be set in context before calling this
initialize_archetype_storage :: (archetype: u16) -> Archetype_Storage {
	storage: Archetype_Storage;
	data := get_archetype_data(archetype);

	storage.entity_component_mask = data.entity_component_mask;
	storage.archetype_component_mask = data.archetype_component_mask;

	array_resize(*storage.entity_components, data.entity_components.count);

	for data.entity_components {
		storage.entity_components[it_index].type = it;
		storage.entity_components[it_index].stride = get_entity_component_size(it);
	}

	archetype_components_total_size : u32;
	for data.archetype_components {
		archetype_components_total_size += get_archetype_component_size(it);
	}
	array_resize(*storage.archetype_components, archetype_components_total_size);

	storage.tags = data.tags;
	storage.chunk_size = data.chunk_size;
	return storage;
}

initialize_archetype_storage :: (archetype: Type) -> Archetype_Storage {
	return initialize_archetype_storage(get_archetype_storage_index(archetype));
}

// Components

Entity_Component_Storage :: struct {
	type			: Type;
	data			: [..]u8;		// Raw data, this is the array where all the entity entity_components are stored linearly
	stride			: u32;			// Size of one component in bytes
}

array_view :: ($T: Type, storage: *Entity_Component_Storage, count: u32) -> []T {
    result: []T = ---;
    result.data = cast,no_check(*T) storage.data.data;
    result.count = count;
    return result;
}

// Archetypes
Archetype_Storage :: struct {
	initialized					: bool;
	entity_components 			: [..]Entity_Component_Storage;
	entity_component_mask 		: Bit_Field(MAX_ENTITY_COMPONENTS);
	
	archetype_components		: [..]u8;
	archetype_component_mask	: Bit_Field(MAX_ARCH_COMPONENTS);

	tags						: ZTags;
	
	// Entities
	num_entities			: u32;
	free_indices			: [..]u32; // Free-list for indices
	generations				: [..]u16; // Generations for each index
	alive_mask				: Bit_Field(MAX_ENTITIES_PER_ARCHETYPE);

	// Autogenerate this from archetype data later
	chunk_size				: u32 = DEFAULT_ENTITY_CHUNK_SIZE;
}

get_entity_component :: (world: *ZWorld, entity: ZEntity, $T: Type) -> *T, bool {
	storage := get_EC_storage_ptr(world, get_archetype(entity.archetype), T);
	if !storage {
		return null, false;
	}
	offset := entity.index * storage.stride;
	return cast,no_check(*T) *storage.data[offset], true;
}

get_entity_component :: (storage: *Entity_Component_Storage, idx: u32,  $T: Type) -> *T {
	offset := idx * storage.stride;
	return cast,no_check(*T) *storage.data[offset];
} 

ensure_component_capacity :: (world: *ZWorld, storage: *Archetype_Storage, needed_count: u32) {    
	for *comp_storage: storage.entity_components {
		needed_bytes := needed_count * comp_storage.stride;
		if comp_storage.data.count < needed_bytes {
			array_resize(*comp_storage.data, needed_bytes);
		}
		// This might "leak" the old allocation in the pool, but who cares?
		// We reset the entire pool between turns anyway, but worth keeping in mind
	}
}