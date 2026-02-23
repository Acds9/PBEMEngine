#import "Math";

Entity_Component :: struct{}

Position :: struct {
	using #as entity_component: Entity_Component;
	value : Vector3;
}

Rotation :: struct {
	using #as entity_component: Entity_Component;
	value : Rotor = .{1,0,0,0};

	default :: (using self: *Rotation) {
		value = ROTOR_IDENTITY;
	}
}

Scale :: struct {
	using #as entity_component: Entity_Component;
	value : Vector3 = .{1,1,1}; 
}

Linear_Velocity :: struct{
	using #as entity_component: Entity_Component;

	value : Vector3;
}

Rotational_Velocity :: struct {
	using #as entity_component: Entity_Component;
	value : Vector3;
}

Thrust :: struct {
	using #as entity_component: Entity_Component;
	value : float;
}

Representation_Flags :: enum_flags u8 {
	TRANSFORM_DIRTY;
}

Entity_Representation_Flags :: struct {
	using #as entity_component: Entity_Component;
	flags : Representation_Flags;
} @no_ser

Mesh_Render_Proxy_EC :: struct {
	using #as entity_component: Entity_Component;
	value	: u32;
} @no_ser // TODO: Fix no_ser now that we know how to, look in serialization_meta.jai

Point_Light_Component :: struct {
	using #as entity_component: Entity_Component;

	color			: Vector4;
	light_address	: u32; 
	radius			: float;
}

Archetype_Component :: struct{}

Mesh_Rep :: struct {
	using #as archetype_component: Archetype_Component;

	value		: string; // String for now, maybe should be an autogenned enum?
} @no_ser

Tag_Component :: struct{} // Maybe this should just be an enum