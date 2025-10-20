Query_Flags		:: enum_flags u8 {
	CHUNK_PREFETCH;
	PARALLEL_SAFE;
	SORTED;
}

Query :: struct {
}
// TODO: chec what's generated, indices are fucked
Query_Position_Randomizer :: struct {
	using #as query: Query;
	
	ENTITY_COMPONENTS 		:: Type.[Scale];
	ARCHETYPE_COMPONENTS 	:: Type.[];
	TAGS					:: ZTags.SHIP;

	QUERY_FLAGS				:: Query_Flags.CHUNK_PREFETCH;
}

Query_Update_Render_Proxy :: struct {
	using #as query: Query;
	
	ENTITY_COMPONENTS 		:: Type.[Position, Rotation, Scale];
	ARCHETYPE_COMPONENTS 	:: Type.[];
	TAGS					:: ZTags.SHIP;

	QUERY_FLAGS				:: Query_Flags.CHUNK_PREFETCH;
}