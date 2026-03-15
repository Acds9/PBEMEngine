// Intel level is the SERVER-SIDE value that determines what a specific player knows about a specific entity
// Intel levels are always per-entity per-player
// When serializing the per-player turn files the server uses intel level to determine which components will be serialized 
// Intel level is never sent to the player, instead a u8 is serialized before the component data blob

INTEL_LEVEL :: enum u8 {
	NONE;
	SIGNAL;
	LOW;
	MEDIUM;
	HIGH;
	FULL;
}

INTEL_LEVEL_COUNT : u8 : #run type_info(INTEL_LEVEL).names.count;
INTEL_LEVEL_MAX : u8 : INTEL_LEVEL_COUNT-1; // Just because it's handy
INTEL_LEVEL_INVALID : u8 : 255;

INTEL_NOTES :: #run () -> [INTEL_LEVEL_COUNT]string {
	notes : [INTEL_LEVEL_COUNT]string;
	for *notes {
		<<it = tprint("required_intel_%", it_index);
	}
	return notes;
}();
