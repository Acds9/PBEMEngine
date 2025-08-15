#import "Basic";
// World

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
	#if !arch_gen { // disable if we're generating archetype code, in which case this won't be ready to call get_arch_index, but this isn't very elegant, maybe we can do something better than this?
		<<storage = initialize_archetype_storage(archetype, allocator);
	}
	storage.initialized = true;
}

get_archetype_storage :: (world: *ZWorld, archetype: Type) -> *Archetype_Storage {
	return *world.world_archetypes[get_arch_index(archetype)];
}

tick_world :: (world: *ZWorld, delta_time: float64) {
	flush_observers(world);
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