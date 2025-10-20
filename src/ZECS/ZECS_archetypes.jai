ZTags :: enum_flags u64 {
	SHIP;
	PROJECTILE;
	COMPONENT;
}

Archetype :: struct{
}

Archetype_Ship :: struct{
	using #as archetype: Archetype;

	ENTITY_COMPONENTS    	:: Type.[Position, Rotation, Scale];
    ARCHETYPE_COMPONENTS 	:: Type.[Mesh_Rep];
	TAGS					:: ZTags.SHIP;
	// TODO: Why not just define an initializer function instead that sets the data when an archetype is instantiated?
	DEFAULT_Mesh_Rep		:: Mesh_Rep.{mesh_name = "Test"};  // Could put some sort of insert macro that adds DEFAULT_ automatically to tagged vars? 

	CHUNK_SIZE				: u32 : 32;
}; 

Archetype_Test :: struct{
	using #as archetype: Archetype;

	ENTITY_COMPONENTS    	:: Type.[Position, Rotation, Scale];
    ARCHETYPE_COMPONENTS 	:: Type.[Mesh_Rep];
	TAGS					:: ZTags.SHIP;
	// TODO: Why not just define an initializer function instead that sets the data when an archetype is instantiated?
	DEFAULT_Mesh_Rep		:: Mesh_Rep.{mesh_name = "Test"};  // Could put some sort of insert macro that adds DEFAULT_ automatically to tagged vars? 

	CHUNK_SIZE				: u32 : 32;
}; 