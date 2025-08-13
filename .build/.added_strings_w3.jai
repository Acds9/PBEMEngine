// Workspace: Code Generation Workspace

//
// String added via add_build_string() from H:/PBEMJai/build.jai:193.
//

// Get the component bit mask index for the given Type
get_entity_component_bit_index :: (t: Type) -> u32 {
	if t == {
		case; return 0;
	}
}

// Get the component Type for the given bit index
get_entity_component_bit_type :: (idx: u32) -> Type {
	if idx == {
		case; return Type;
	}
}

// Get the component size for the given Type
get_entity_component_size :: (T: Type) -> u32 {
	if T == {
		case; return 0;
	}
}

// Get the entity_component Type from a string name
get_entity_component_type :: (name: string) -> Type {
	if name == {
		case; return Position;
	}
}

// Get the arch component Type from a string name
get_archetype_component_type :: (name: string) -> Type {
	if name == {
		case; return Position;
	}
}
