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

Gen_Intel_Level_Members :: struct {
    level: u8;
    members: [..]*Type_Info_Struct_Member;
}
get_struct_intel_level_members :: (t: *Type_Info_Struct, out: *[..]Gen_Intel_Level_Members){
	for *member: t.members {
		if member.flags & Type_Info_Struct_Member.Flags.CONSTANT || member.flags & Type_Info_Struct_Member.Flags.AS {
			continue; // using #as will have entity_component as member, we don't want that
		}
		intel_level := get_intel_level_notes(member.notes);

		for <<out {
			if it.level == intel_level {
				array_add(*it.members, member);
				continue member;
			}
		}
		members: [..]*Type_Info_Struct_Member;
		array_add(*members, member);
		array_add(out, Gen_Intel_Level_Members.{intel_level, members});
	}
}