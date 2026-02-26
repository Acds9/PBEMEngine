#import "Basic";
Observer_Flags :: enum_flags u32 {
	RENDERING;
	AUTOREGISTER;
}

Observer :: struct {}

Observer_Ship_Spawn_Render_Mesh :: struct {
	using #as observer: Observer;

	ENTITY_COMPONENTS 		:: Type.[Position, Rotation, Scale, Mesh_Render_Proxy_EC];
	ARCHETYPE_COMPONENTS 	:: Type.[Mesh_Rep];
	TAGS					:: ZTags.SHIP;

	FLAGS					:: Observer_Flags.AUTOREGISTER | .RENDERING;
	WORLD_TYPES				:: World_Type.REPLAY;
	PRIORITY				:: 0;
}

Observer_Light_Spawn_Render_Light :: struct {
	using #as observer: Observer;

	ENTITY_COMPONENTS 		:: Type.[Position, Point_Light_Component];
	ARCHETYPE_COMPONENTS 	:: Type.[];
	TAGS					:: ZTags.LIGHT;

	FLAGS					:: Observer_Flags.AUTOREGISTER | .RENDERING;
	WORLD_TYPES				:: World_Type.REPLAY;
	PRIORITY				:: 0;
}