
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

// Get the component storage index for the given Type
get_archetype_component_index :: (t: Type) -> u32 {
	if t == {
		case Mesh_Rep; return 0;
		case; return 0;
	}
}

// Get the component Type for the given index
get_archetype_component_type :: (idx: u32) -> Type {
	if idx == {
		case 0; return Mesh_Rep;
		case; return Type;
	}
}

// Get the component size for the given Type
get_archetype_component_size :: (T: Type) -> u32 {
	if T == {
		case Mesh_Rep; return size_of(Mesh_Rep);
		case; return 0;
	}
}

// Get the component storage index for the given Type
get_tag_index :: (t: Type) -> u32 {
	if t == {
		case; return 0;
	}
}

// Get the component Type for the given index
get_tag_type :: (idx: u32) -> Type {
	if idx == {
		case; return Type;
	}
}

// Get the entity_component Type from a string name
get_entity_component_type :: (name: string) -> Type {
	if name == {
		case "Position"; return Position;
		case "Rotation"; return Rotation;
		case "Scale"; return Scale;
		case; return Position;
	}
}

// Get the arch component Type from a string name
get_arch_component_type :: (name: string) -> Type {
	if name == {
		case "Mesh_Rep"; return Mesh_Rep;
		case; return Position;
	}
}
