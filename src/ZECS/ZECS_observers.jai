#import "Basic";
Observer_Flags :: enum_flags u8 {
	NONE;
}


Observer :: struct {}

Observer_Ship_Spawn :: struct {
	using #as observer: Observer;

	ENTITY_COMPONENTS 		:: Type.[Position, Rotation, Scale, Mesh_Instance_Address];
	ARCHETYPE_COMPONENTS 	:: Type.[Mesh_Rep];
	TAGS					:: ZTags.SHIP;

	FLAGS					:: Observer_Flags.NONE;
	PRIORITY				:: 0;
}