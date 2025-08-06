math :: #import "Math";

Entity_Component :: struct{}

Position :: struct{
	using #as entity_component: Entity_Component;
	pos : Vector3;
}

Rotation :: struct{
	using #as entity_component: Entity_Component;
	rot : Quaternion = QUAT_IDENTITY;
}

Scale :: struct{
	using #as entity_component: Entity_Component;
	scale : Vector3 = VECTOR_ONE;
}

Archetype_Component :: struct{}

Tag_Component :: struct{} // Maybe this should just be an enum


// Archetypes, move this out to its own file


Archetype :: struct (components: [$N]Type){
	chunk_size 					:	u32 = 32; 	// 32 default AKA "cold", raise to 64-256 for "hotter" archetypes;

	entity_components			:= 	components;
}

Archetype_Ship :: Archetype(Type.[Position, Rotation, Scale]).{
	chunk_size = 32
}; 

