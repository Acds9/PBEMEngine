get_intel_level_notes :: (notes: []string) -> u8 {
	for note: notes {
		for INTEL_NOTES { // Faster to do this, or to search substring? Probably doens't matter at compile time
			if note == it {
				found, note_string, level_string := split_from_right(it, "_");
				assert(found, tprint("Attempted to split the intel note but no _ separator was found in note %", it));
				level, success := parse_int(*level_string, u8);
				assert(success, tprint("Attempted to prase the intel level as int in note % but failed", it));
				return level;
			}
		}
	}
	return 0;
}

is_component_in_intel_range :: (component: Type, archetype: u16, intel_level: INTEL_LEVEL) -> bool {
	archetype_data := get_archetype_data(archetype);
	intel_bit_field := *archetype_data.component_intel_bitfield[intel_level];
	return bit_test(intel_bit_field, get_entity_component_index(archetype, component));
}