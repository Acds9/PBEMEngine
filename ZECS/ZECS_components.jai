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
	scale : Vector3 = .{1,1,1};
}

Archetype_Component :: struct{}

Mesh_Rep :: struct {
	using #as archetype_component: Archetype_Component;

	mesh_name		: string; // String for now, maybe should be an autogenned enum?
}

Tag_Component :: struct{} // Maybe this should just be an enum


// Archetypes, move this out to its own file


Archetype :: struct{
}

Archetype_Ship :: struct{
	using #as archetype: Archetype;

	ENTITY_COMPONENTS    	:: Type.[Position, Rotation, Scale];
    ARCHETYPE_COMPONENTS 	:: Type.[Mesh_Rep];
	TAGS					:: u64;

	DEFAULT_MESH_REP		:: Mesh_Rep.{mesh_name = "Test"};  // Could put some sort of insert macro that adds DEFAULT_ automatically to tagged vars? 

	CHUNK_SIZE				: u32 : 32;
}; 