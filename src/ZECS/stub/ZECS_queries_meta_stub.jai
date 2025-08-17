#import "Flat_Pool";

Entity_Component_Storage :: struct {
	type			: Type;
	data			: [..]u8;		
	stride			: u32;			
}
Archetype_Component_Storage :: struct {}

DEFAULT_ENTITY_CHUNK_SIZE :: 32;
MAX_ENTITIES_PER_ARCHETYPE :: 2048;
Archetype_Storage :: struct {
	initialized					: bool;
	entity_components 			: [..]Entity_Component_Storage;
	entity_component_mask 		: Bit_Field(MAX_ENTITY_COMPONENTS);
	
	archetype_components		: [..]Archetype_Component_Storage;
	archetype_component_mask	: Bit_Field(MAX_ARCH_COMPONENTS);

	tags						: ZTags;
	
	num_entities			: u32;
	free_indices			: [..]u32; 
	generations				: [..]u16; 
	alive_mask				: Bit_Field(MAX_ENTITIES_PER_ARCHETYPE); 

	
	chunk_size				: u32 = DEFAULT_ENTITY_CHUNK_SIZE;
}

ZEntity :: struct
{
	index 		: u32;
	gen			: u16;
	archetype	: u16;
}

ZWorld :: struct {
	world_archetypes 	: [MAX_ARCHETYPES]Archetype_Storage;
	world_entities 		: [..]ZEntity;

	// Memory
	world_pool			: Flat_Pool;

	observer_registry	: Observer_Registry;
	observer_buffer		: Observer_Buffer;

}

Observer_Registry :: struct {
	on_created: 	[MAX_ARCHETYPES][..]Observer_Entry;
	on_destroyed:	[MAX_ARCHETYPES][..]Observer_Entry;
}

Observer_Buffer :: struct {
	created:	[MAX_ARCHETYPES][..]ZEntity;
	destroyed:	[MAX_ARCHETYPES][..]ZEntity;

	reset :: (){};
}

get_entity_component :: (world: *ZWorld, entity: ZEntity, $T: Type) -> *T {return null;}


get_archetype_component :: (world: *ZWorld, archetype: u16, $T: Type) -> *T {return null;};

Observer_Entry :: struct {
	priority	: u8;
	proc		: (world: *ZWorld, arch: u16, entity_indices: []ZEntity);
}