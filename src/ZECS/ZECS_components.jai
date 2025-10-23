#import "Math";

Entity_Component :: struct{}

Position :: struct{
	using #as entity_component: Entity_Component;
	pos : Vector3;

	default :: (using self: *Position) {
		pos = VECTOR_ZERO;
	}
}

Rotation :: struct{
	using #as entity_component: Entity_Component;
	rot : Rotor;

	default :: (using self: *Rotation) {
		rot = ROTOR_IDENTITY;
	}
}

Scale :: struct{
	using #as entity_component: Entity_Component;
	scale : Vector3 = .{1,1,1}; //TODO: this works, maybe keep it instead of default?

	default :: (using self: *Scale) {
		scale = VECTOR_ONE;
	}
}

Representation_Flags :: enum_flags u8 {
	TRANSFORM_DIRTY;
}

Entity_Representation_Flags :: struct {
	using #as entity_component: Entity_Component;
	flags : Representation_Flags;

	default :: (using self: *Entity_Representation_Flags) {
		flags = 0;
	}
}

Mesh_Instance_Address :: struct {
	using #as entity_component: Entity_Component;

	mesh_address	: u64;

	default :: (using self: *Mesh_Instance_Address) {
		mesh_address = 0;
	}
}

Archetype_Component :: struct{}

Mesh_Rep :: struct {
	using #as archetype_component: Archetype_Component;

	mesh_name		: string; // String for now, maybe should be an autogenned enum?
}

Tag_Component :: struct{} // Maybe this should just be an enum