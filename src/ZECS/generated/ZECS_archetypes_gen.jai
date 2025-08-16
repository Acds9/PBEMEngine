
// Archetype data struct
Archetype_Data :: struct {
	name: string;
	index: u16;
	type: Type;
	entity_component_mask: Bit_Field(MAX_ENTITY_COMPONENTS);
	archetype_component_mask: Bit_Field(MAX_ARCH_COMPONENTS);
	entity_components: []Type;
	entity_components_sizes: []u32;
	entity_components_strides: []u32;
	archetype_components: []Type;
	tags: ZTags;
	chunk_size: u32;
	initializer: u32;
}

// Database of all archetype data
ARCHETYPE_DATABASE :: Archetype_Data.[
	.{
		name = "Archetype_Ship",
		index = 0,
		type = Archetype_Ship,

		entity_component_mask		= .{.[14]},
		archetype_component_mask	= .{.[1]},

		entity_components			= .[Position, Rotation, Scale],
		entity_components_sizes		= .[12, 16, 12],
		entity_components_strides	= .[12, 16, 12],

		archetype_components		= .[Mesh_Rep],

		tags						= cast,no_check(ZTags)1,
		chunk_size					= 32,
		initializer					= 32,
	}
];

// Archetype Data Getters
get_archetype_data :: (idx: u16) -> *Archetype_Data{
	return *ARCHETYPE_DATABASE[idx];
};
get_archetype_data :: (t: Type) -> *Archetype_Data{
	return *ARCHETYPE_DATABASE[get_arch_index(t)];
};

// Get storage index for archetype type
get_arch_index :: (t: Type) -> u16 {
	if t == {
		case Archetype_Ship; return 0;
		case; return 0;
	}
}

// Get archetype Type for storage index
get_index_arch :: (idx: u16) -> Type {
	if idx == {
		case 0; return Archetype_Ship;
		case; return void;
	}
}

// Get component storage for archetype/component pair
get_e_c_storage_ptr :: (world: *ZWorld, arch: Type, $T: Type) -> *Entity_Component_Storage {
	if arch == {
		case Archetype_Ship;
			a_s := *world.world_archetypes[get_arch_index(Archetype_Ship)];
			if T == {
				case Position; return *a_s.entity_components[0];
				case Rotation; return *a_s.entity_components[1];
				case Scale; return *a_s.entity_components[2];
				case; return null;
			}
		case; return null;
	}
}

// Get the arch Type from a string name
get_arch_type :: (name: string) -> Type {
	if name == {
		case "Archetype_Ship"; return Archetype_Ship;
		case; return void;
	}
}

// Archetype component getters
get_Archetype_Ship_entity_component_index :: (t: Type) -> u16  {
	if t==  {
		case Position; return 0;
		case Rotation; return 1;
		case Scale; return 2;
		case; return 0;
	}
}
get_Archetype_Ship_arch_component_index :: (t: Type) -> u16  {
	if t==  {
		case Mesh_Rep; return 0;
		case; return 0;
	}
}
get_Archetype_Ship_entity_component_type :: (idx: u16) -> Type  {
	if idx==  {
		case 0; return Position;
		case 1; return Rotation;
		case 2; return Scale;
		case; return void;
	}
}
get_Archetype_Ship_arch_component_type :: (idx: u16) -> Type  {
	if idx==  {
		case 0; return Mesh_Rep;
		case; return void;
	}
}
get_entity_component_index :: (archetype: Type, entity_component: Type) -> u16 {
	if archetype == {
		case Archetype_Ship; if entity_component == {
			case Position; return 0;
			case Rotation; return 1;
			case Scale; return 2;
			case; return 0;
		}
		case; return 0;
	}
}
get_archetype_component_index :: (archetype: Type, archetype_component: Type) -> u16 {
	if archetype == {
		case Archetype_Ship; if archetype_component == {
			case Mesh_Rep; return 0;
			case; return 0;
		}
		case; return 0;
	}
}
get_entity_component_type :: (archetype: Type, index: u16) -> Type {
	if archetype == {
		case Archetype_Ship; if index == {
			case 0; return Position;
			case 1; return Rotation;
			case 2; return Scale;
			case; return Position;
		}
	case; return void;
	}
}
get_archetype_component_type :: (archetype: Type, index: u16) -> Type {
	if archetype == {
		case Archetype_Ship; if index == {
			case 0; return Mesh_Rep;
			case; return void;
		}
	case; return void;
	}
}

// Initialize entity components for Archetype_Ship
init_entity_components_Archetype_Ship :: (storage: *Archetype_Storage, entity_index: u32) {
	Position_ptr := cast(*Position) (storage.entity_components[0].data.data + entity_index * storage.entity_components[0].stride);
	<<Position_ptr = Position.{};
	Rotation_ptr := cast(*Rotation) (storage.entity_components[1].data.data + entity_index * storage.entity_components[1].stride);
	<<Rotation_ptr = Rotation.{};
	Scale_ptr := cast(*Scale) (storage.entity_components[2].data.data + entity_index * storage.entity_components[2].stride);
	<<Scale_ptr = Scale.{};
}

// Initialize entity components for archetype
init_entity_components :: (t: Type, storage: *Archetype_Storage, entity_index: u32) {
	if t == {
		case Archetype_Ship; init_entity_components_Archetype_Ship(storage, entity_index);
		case; // Unknown archetype
	}
}
