#import "Math";

Entity_Component :: struct{}

Position :: struct{
	using #as entity_component: Entity_Component;
	pos : Vector3;
}

Rotation :: struct{
	using #as entity_component: Entity_Component;
	rot : Rotor = .{1,0,0,0};

	default :: (using self: *Rotation) {
		rot = ROTOR_IDENTITY;
	}
}

Scale :: struct{
	using #as entity_component: Entity_Component;
	scale : Vector3 = .{1,1,1}; 
}

Representation_Flags :: enum_flags u8 {
	TRANSFORM_DIRTY;
}

Entity_Representation_Flags :: struct {
	using #as entity_component: Entity_Component;
	flags : Representation_Flags;
}

Mesh_Instance_Address :: struct {
	using #as entity_component: Entity_Component;

	mesh_address	: u64;
}

Archetype_Component :: struct{}

Mesh_Rep :: struct {
	using #as archetype_component: Archetype_Component;

	mesh_name		: string; // String for now, maybe should be an autogenned enum?
}

Tag_Component :: struct{} // Maybe this should just be an enum