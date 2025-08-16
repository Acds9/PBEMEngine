#import "Flat_Pool";
ZWorld :: struct {
	world_archetypes 	: [MAX_ARCHETYPES]Archetype_Storage;
	world_entities 		: [..]ZEntity;

	// Memory
	world_pool			: Flat_Pool;

}

MAX_ENTITIES_PER_ARCHETYPE :: 2048;
DEFAULT_ENTITY_CHUNK_SIZE :: 32;

Entity_Component_Storage :: struct {
	type			: Type;
	data			: [..]u8;		
	stride			: u32;			
}
ZEntity :: struct {
}
Archetype_Component_Storage :: struct {}

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