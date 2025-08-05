
//
// String added via add_build_string() from H:/PBEMJai/build.jai:175.
//
// ZECS Constants
MAX_ENTITY_COMPONENTS :: 3;
MAX_ARCH_COMPONENTS :: 0;
MAX_TAGS :: 0;


//
// String added via add_build_string() from H:/PBEMJai/build.jai:181.
//

// Get the component storage index for the given Type
get_entity_component_index :: (t: Type) -> u32 {
	if t == {
		case Position; return 0;
		case Rotation; return 1;
		case Scale; return 2;
		case; return 0;
	}
}

// Get the component Type for the given index
get_entity_component_type :: (idx: u32) -> Type {
	if idx == {
		case 0; return Position;
		case 1; return Rotation;
		case 2; return Scale;
		case; return Type;
	}
}

// Get the component size for the given Type
get_entity_component_size :: (T: Type) -> u32 {
	if T == {
		case Position; return size_of(Position);
		case Rotation; return size_of(Rotation);
		case Scale; return size_of(Scale);
		case; return 0;
	}
}

//
// String added via add_build_string() from H:/PBEMJai/build.jai:201.
//

// Get the index for the given Type
get_arch_index :: (t: Type) -> u16 {
	if t == {
		case type_of(Archetype_Ship); return 0;
		case; return 0;
	}
}

//
// String added via add_build_string() from H:/PBEMJai/build.jai:204.
//

// Initializer getter for archetypes
entity_initializer_switch :: (t: Type) -> u16 {
	if t == {
		case type_of(Archetype_Ship); return 0;
		case; return 0;
	}
}

//
// String added via add_build_string() from H:/PBEMJai/build.jai:206.
//

// Entity initializer for Archetype_Ship
Initializer_Archetype_Ship :: (as: *Archetype_Storage, idx: u32) {
	Position_ptr := cast(*Position) (as.entity_components[get_entity_component_index(Position)].data.data + idx * as.entity_components[get_entity_component_index(Position)].stride);
	Rotation_ptr := cast(*Rotation) (as.entity_components[get_entity_component_index(Rotation)].data.data + idx * as.entity_components[get_entity_component_index(Rotation)].stride);
	Scale_ptr := cast(*Scale) (as.entity_components[get_entity_component_index(Scale)].data.data + idx * as.entity_components[get_entity_component_index(Scale)].stride);
}
