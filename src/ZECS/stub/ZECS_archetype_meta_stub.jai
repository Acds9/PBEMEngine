#import "Flat_Pool";
ZWorld :: struct {
	world_archetypes 	: [MAX_ARCHETYPES]Archetype_Storage;
	world_entities 		: [..]ZEntity;

	// Memory
	world_pool			: Flat_Pool;
	allocator			: Allocator;
}

MAX_ENTITIES_PER_ARCHETYPE :: 2048;
DEFAULT_ENTITY_CHUNK_SIZE :: 32;

Entity_Component_Storage :: struct {
	type			: Type;
	data			: [..]u8;		
	stride			: u32;			
}
ZEntity :: struct {
	index 	: u32;
	gen		: u16;
	archetype : u16;
}
Archetype_Storage :: struct {
	initialized					: bool;
	entity_components 			: [..]Entity_Component_Storage;
	entity_component_mask 		: Bit_Field(MAX_ENTITY_COMPONENTS);
	
	archetype_components		: [..]u8;
	archetype_component_mask	: Bit_Field(MAX_ARCH_COMPONENTS);

	tags						: ZTags;
	
	num_entities			: u32;
	free_indices			: [..]u32; 
	generations				: [..]u16; 
	alive_mask				: Bit_Field(MAX_ENTITIES_PER_ARCHETYPE); 

	
	chunk_size				: u32 = DEFAULT_ENTITY_CHUNK_SIZE;
}

get_archetype_storage :: (world: *ZWorld, archetype: Type) -> *Archetype_Storage {return null;}
initialize_archetype_storage :: (archetype: Type) -> Archetype_Storage {return .{};}
get_archetype_component :: (world: *ZWorld, archetype: Type, $T: Type) -> *T {return null;};
get_entity_component :: (world: *ZWorld, entity: ZEntity, $T: Type) -> *T, bool {return null, false;}

serialize_to_buffer_string :: (dest: *[..]u8, src: string) {}

serialize_to_buffer :: (dest: *[..]u8, src: *void, count: s64) {}

serialize_to_buffer :: (dest: *[..]u8, src: *$T) {}

serialize_to_buffer :: (dest: *[..]u8, src: *void, offset: *s64, count: s64) {}

deserialize_from_buffer :: (dest: *void, src: []u8, offset: *s64, count: s64) {}

deserialize_from_buffer :: (dest: *$T, src: []u8, offset: *s64) {}

deserialize_from_buffer_string :: (src: []u8, offset: *s64) -> string {return "";}