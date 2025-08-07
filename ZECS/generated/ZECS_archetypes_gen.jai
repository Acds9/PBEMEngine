
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
	Position_ptr := cast(*Position) (storage.entity_components[get_entity_component_index(Position)].data.data + entity_index * storage.entity_components[get_entity_component_index(Position)].stride);
	<<Position_ptr = Position.{};
	Rotation_ptr := cast(*Rotation) (storage.entity_components[get_entity_component_index(Rotation)].data.data + entity_index * storage.entity_components[get_entity_component_index(Rotation)].stride);
	<<Rotation_ptr = Rotation.{};
	Scale_ptr := cast(*Scale) (storage.entity_components[get_entity_component_index(Scale)].data.data + entity_index * storage.entity_components[get_entity_component_index(Scale)].stride);
	<<Scale_ptr = Scale.{};
}

// Initialize entity components for archetype
init_entity_components :: (t: Type, storage: *Archetype_Storage, entity_index: u32) {
	if t == {
		case Archetype_Ship; init_entity_components_Archetype_Ship(storage, entity_index);
		case; // Unknown archetype
	}
}
