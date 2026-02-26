Query_Flags		:: enum_flags u32 {
	NON_PARALLEL;
	ATOMIC_COUNTER;
	RENDERING;
}

Query :: struct {
}

Query_Update_Render_Proxy :: struct {
	using #as query: Query;
	
	ENTITY_COMPONENTS 		:: Type.[Position, Rotation, Scale, Mesh_Render_Proxy_EC];
	ARCHETYPE_COMPONENTS 	:: Type.[];
	TAGS					:: ZTags.SHIP;

	QUERY_FLAGS				:: Query_Flags.RENDERING;
	WORLD_TYPES				:: World_Type.REPLAY;
}

Query_Debug_Draw_Point_Light :: struct {
	using #as query: Query;
	
	ENTITY_COMPONENTS 		:: Type.[Position, Point_Light_Component];
	ARCHETYPE_COMPONENTS 	:: Type.[];
	TAGS					:: ZTags.LIGHT;

	QUERY_FLAGS				:: Query_Flags.NON_PARALLEL | .RENDERING;
	WORLD_TYPES				:: World_Type.REPLAY;
}

Query_Debug_Draw_AABB :: struct {
	using #as query: Query;
	
	ENTITY_COMPONENTS 		:: Type.[Position, Rotation, Scale, Mesh_Render_Proxy_EC];
	ARCHETYPE_COMPONENTS 	:: Type.[];
	TAGS					:: ZTags.SHIP;

	QUERY_FLAGS				:: Query_Flags.NON_PARALLEL | .RENDERING;
	WORLD_TYPES				:: World_Type.REPLAY;
}

Query_Spatialize_Entities :: struct {
	using #as query: Query;
	
	ENTITY_COMPONENTS 		:: Type.[Position, Mesh_Render_Proxy_EC]; // TODO: not the best way to determine what needs spatializing
	ARCHETYPE_COMPONENTS 	:: Type.[];
	TAGS					:: ZTags.SHIP;

	QUERY_FLAGS				:: Query_Flags.ATOMIC_COUNTER;
	WORLD_TYPES				:: World_Type.SIMULATION;
}

Query_Update_Physics :: struct {
	using #as query: Query;
	
	ENTITY_COMPONENTS 		:: Type.[Position, Rotation, Thrust, Linear_Velocity, Rotational_Velocity];
	ARCHETYPE_COMPONENTS 	:: Type.[];
	TAGS					:: ZTags.SHIP;

	QUERY_FLAGS				:: 0;
	WORLD_TYPES				:: World_Type.SIMULATION;
}
