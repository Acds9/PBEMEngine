#import "Basic";
fp :: #import "Flat_Pool"(DEFAULT_VIRTUAL_MEMORY_RESERVE = DEFAULT_POOL_SIZE);

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

