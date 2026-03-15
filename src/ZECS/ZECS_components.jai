#import "Math";

Entity_Component :: struct{}

Position :: struct @serialize @intel_level_1 {
	using #as entity_component: Entity_Component;
	value : Vector3;

	interpolate :: (dst: *void, a: *void, b: *void, t: float32) {
		d := cast,no_check(*Position) dst;
		d.value = lerp((cast,no_check(*Position)a).value, (cast,no_check(*Position)b).value, t);
	}
}

Rotation :: struct @serialize {
	using #as entity_component: Entity_Component;
	value : Rotor = .{1,0,0,0};
}

Scale :: struct @serialize {
	using #as entity_component: Entity_Component;
	value : Vector3 = .{1,1,1};
}

Linear_Velocity :: struct @serialize {
	using #as entity_component: Entity_Component;

	value : Vector3;
}

Rotational_Velocity :: struct @serialize {
	using #as entity_component: Entity_Component;
	value : Vector3;
}

Thrust :: struct @serialize {
	using #as entity_component: Entity_Component;
	value : float;
}

Representation_Flags :: enum_flags u8 {
	TRANSFORM_DIRTY;
}

Entity_Representation_Flags :: struct {
	using #as entity_component: Entity_Component;
	flags : Representation_Flags;
}

Mesh_Render_Proxy_EC :: struct {
	using #as entity_component: Entity_Component;
	value	: u32;
}

Point_Light_Component :: struct @serialize {
	using #as entity_component: Entity_Component;

	color			: Vector4;
	light_address	: u32;
	radius			: float;
}

Archetype_Component :: struct{}

Mesh_Rep :: struct {
	using #as archetype_component: Archetype_Component;

	value		: string; // String for now, maybe should be an autogenned enum?
}

Tag_Component :: struct{} // Maybe this should just be an enum
