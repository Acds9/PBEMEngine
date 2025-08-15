// Workspace: Code Generation Workspace

//
// String added via add_build_string() from H:/PBEMJai/component_build.jai:103.
//

// Get the component bit mask index for the given Type
get_entity_component_bit_index :: (t: Type) -> u32 {
	if t == {
		case Entity_Representation_Flags; return 0;
		case Position; return 1;
		case Rotation; return 2;
		case Scale; return 3;
		case; return 0;
	}
}

// Get the component Type for the given bit index
get_entity_component_bit_type :: (idx: u32) -> Type {
	if idx == {
		case 0; return Entity_Representation_Flags;
		case 1; return Position;
		case 2; return Rotation;
		case 3; return Scale;
		case; return Type;
	}
}

// Get the component size for the given Type
get_entity_component_size :: (T: Type) -> u32 {
	if T == {
		case Entity_Representation_Flags; return size_of(Entity_Representation_Flags);
		case Position; return size_of(Position);
		case Rotation; return size_of(Rotation);
		case Scale; return size_of(Scale);
		case; return 0;
	}
}

// Get the entity_component Type from a string name
get_entity_component_type :: (name: string) -> Type {
	if name == {
		case "Entity_Representation_Flags"; return Entity_Representation_Flags;
		case "Position"; return Position;
		case "Rotation"; return Rotation;
		case "Scale"; return Scale;
		case; return Position;
	}
}

// Get the arch component Type from a string name
get_archetype_component_type :: (name: string) -> Type {
	if name == {
		case "Mesh_Rep"; return Mesh_Rep;
		case; return Position;
	}
}
