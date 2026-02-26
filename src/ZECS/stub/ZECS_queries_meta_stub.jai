#import "Flat_Pool";

Entity_Component_Storage :: struct {
	type			: Type;
	data			: [..]u8;		
	stride			: u32;			
}

DEFAULT_ENTITY_CHUNK_SIZE :: 32;
MAX_ENTITIES_PER_ARCHETYPE :: 2048;
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

ZEntity :: struct
{
	index 		: u32;
	gen			: u16;
	archetype	: u16;
}


World_Type :: enum_flags u8 {
	MENU;
	REPLAY;
	SIMULATION;
}

ZWorld :: struct {
	world_archetypes 	: [MAX_ARCHETYPES]Archetype_Storage;
	world_entities 		: [..]ZEntity;

	observer_registry	: Observer_Registry;
	observer_buffer		: Observer_Buffer;

	type				: World_Type;
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

Observer_Entry :: struct {
	priority	: u8;
	proc		: (game_world: *Game_World, entity_indices: []ZEntity);
}

get_entity_component :: (world: *ZWorld, entity: ZEntity, $T: Type) -> *T, bool {return null, false;}
get_archetype_storage :: (world: *ZWorld, archetype: Type) -> *Archetype_Storage {return null;}
initialize_archetype_storage :: (archetype: Type) -> Archetype_Storage {return .{};}
//get_archetype_component :: (world: *ZWorld, archetype: Type, $T: Type) -> *T {return null;};

Game_Instance :: struct {
    world: ZWorld;
    scene: ZScene;
    quit: bool;
    
    // Timing
    frequency: u64;
    last_counter: u64;
    delta_time: float64;
    fps: u32;
}
GAME_STATE : Game_Instance;

ZScene :: struct {
	device_mesh_instances	: *void;
	device_transforms		: *void; 

	device_point_lights		: *void;

	device_debug_mesh_instances 	: *void;
	device_debug_transforms		: *void;
}

Observer_Ship_Spawn_Render_Mesh_Event :: (entity_idx: ZEntity, game_world: *Game_World) {};
Observer_Light_Spawn_Render_Light_Event :: (entity_idx: ZEntity, game_world: *Game_World) {};

serialize_to_buffer_string :: (dest: *[..]u8, src: string) {}

serialize_to_buffer :: (dest: *[..]u8, src: *void, count: s64) {}

serialize_to_buffer :: (dest: *[..]u8, src: *$T) {}

serialize_to_buffer :: (dest: *[..]u8, src: *void, offset: *s64, count: s64) {}

deserialize_from_buffer :: (dest: *void, src: []u8, offset: *s64, count: s64) {}

deserialize_from_buffer :: (dest: *$T, src: []u8, offset: *s64) {}

deserialize_from_buffer_string :: (src: []u8, offset: *s64) -> string {return "";}