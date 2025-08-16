Observer_Flags :: enum_flags u8 {
	NONE;
}

Observer :: struct {}

Observer_Ship_Spawn :: struct {
	using #as observer: Observer;

	ENTITY_COMPONENTS 		:: Type.[Position, Rotation, Scale];
	ARCHETYPE_COMPONENTS 	:: Type.[Mesh_Rep];
	TAGS					:: ZTags.SHIP;

	FLAGS					:: Observer_Flags.NONE;
	PRIORITY				:: 0;

	// THIS CODE IS CALLED PER-ENTITY!
	PROC :: (entity_idx: ZEntity, archetype_idx: u16, world: *ZWorld) {
		print("Ship % created!\n", entity_idx);
	}
}
