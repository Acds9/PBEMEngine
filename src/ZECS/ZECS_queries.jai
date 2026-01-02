Query_Flags		:: enum_flags u32 {
	NON_PARALLEL;
	ATOMIC_COUNTER;
}

Query :: struct {
}

Query_Update_Render_Proxy :: struct {
	using #as query: Query;
	
	ENTITY_COMPONENTS 		:: Type.[Position, Rotation, Scale, Mesh_Render_Proxy_EC];
	ARCHETYPE_COMPONENTS 	:: Type.[];
	TAGS					:: ZTags.SHIP;

	QUERY_FLAGS				:: 0;
}

Query_Debug_Draw_Point_Light :: struct {
	using #as query: Query;
	
	ENTITY_COMPONENTS 		:: Type.[Position, Point_Light_Component];
	ARCHETYPE_COMPONENTS 	:: Type.[];
	TAGS					:: ZTags.LIGHT;

	QUERY_FLAGS				:: Query_Flags.NON_PARALLEL;
}

Query_Debug_Draw_AABB :: struct {
	using #as query: Query;
	
	ENTITY_COMPONENTS 		:: Type.[Position, Rotation, Scale, Mesh_Render_Proxy_EC];
	ARCHETYPE_COMPONENTS 	:: Type.[];
	TAGS					:: ZTags.SHIP;

	QUERY_FLAGS				:: 0;
}

Query_Spatialize_Entities :: struct {
	using #as query: Query;
	
	ENTITY_COMPONENTS 		:: Type.[Position, Mesh_Render_Proxy_EC]; // TODO: not the best way to determine what needs spatializing
	ARCHETYPE_COMPONENTS 	:: Type.[];
	TAGS					:: 0;

	QUERY_FLAGS				:: Query_Flags.ATOMIC_COUNTER;
}