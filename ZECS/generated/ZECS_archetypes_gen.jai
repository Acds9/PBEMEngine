
// Database of all archetype data
ARCHETYPE_DATABASE :: struct {
	Archetype_Ship_Data :: struct {
		Entity_Component_Mask		: Bit_Field(MAX_ENTITY_COMPONENTS) : .{.[7]};
		Archetype_Component_Mask	: Bit_Field(MAX_ARCH_COMPONENTS) : .{.[1]};

		Entity_Components			: [3]Type : .[Position, Rotation, Scale];
		Entity_Components_sizes		: [3]u32 : .[12, 16, 12];
		Entity_Components_strides	: [3]u32 : .[12, 16, 12];

		Archetype_Components		: [1]Type : .[Mesh_Rep];

		Tags						: ZTags : cast,no_check(ZTags)3;
		chunk_size					: u32 : 32;
		initializer					: u32 : 32;
	}
}

// Archetype Storage initializer for Archetype_Ship
initialize_storage_Archetype_Ship :: (alloc: Allocator) -> Archetype_Storage {
	storage: Archetype_Storage;

	storage.entity_components.allocator = alloc;
	storage.archetype_components.allocator = alloc;
	storage.free_indices.allocator = alloc;
	storage.generations.allocator = alloc;

	storage.entity_component_mask = ARCHETYPE_DATABASE.Archetype_Ship_Data.Entity_Component_Mask;
	storage.archetype_component_mask = ARCHETYPE_DATABASE.Archetype_Ship_Data.Archetype_Component_Mask;

	array_resize(*storage.entity_components, ARCHETYPE_DATABASE.Archetype_Ship_Data.Entity_Components.count);
	array_resize(*storage.archetype_components, ARCHETYPE_DATABASE.Archetype_Ship_Data.Entity_Components.count);

	for ARCHETYPE_DATABASE.Archetype_Ship_Data.Entity_Components {
		storage.entity_components[it_index].type = it;
		storage.entity_components[it_index].stride = get_entity_component_size(it);
	}

	storage.archetype_components[0].type = Mesh_Rep;
	storage.archetype_components[0].data = Any.{type = type_info(Mesh_Rep), value_pointer = cast(*void)(*Archetype_Ship.DEFAULT_Mesh_Rep)};
	storage.tags = ARCHETYPE_DATABASE.Archetype_Ship_Data.Tags;
	storage.chunk_size = ARCHETYPE_DATABASE.Archetype_Ship_Data.chunk_size;
	return storage;
}

// Archetype Storage Initializer getter
get_archetype_initializer :: (t: Type) -> Arch_Storage_Initializer  {
	if t == {
	case Archetype_Ship; return initialize_storage_Archetype_Ship;
	case; return null;
	}
}

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
		case; return Archetype;
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
