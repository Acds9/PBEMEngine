#import "Basic";
Observer_Flags :: enum_flags u32 {
	VISUAL;
}

Observer :: struct {}

Observer_Ship_Spawn :: struct {
	using #as observer: Observer;

	ENTITY_COMPONENTS 		:: Type.[Position, Rotation, Scale, Mesh_Render_Proxy_EC];
	ARCHETYPE_COMPONENTS 	:: Type.[Mesh_Rep];
	TAGS					:: ZTags.SHIP;

	FLAGS					:: Observer_Flags.VISUAL;
	PRIORITY				:: 0;
}

Observer_Point_Light_Spawn :: struct {
	using #as observer: Observer;

	ENTITY_COMPONENTS 		:: Type.[Position, Point_Light_Component];
	ARCHETYPE_COMPONENTS 	:: Type.[];
	TAGS					:: ZTags.LIGHT;

	FLAGS					:: Observer_Flags.VISUAL;
	PRIORITY				:: 0;
}