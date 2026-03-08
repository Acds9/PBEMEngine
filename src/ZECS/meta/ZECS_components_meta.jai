#import "Basic";
#import "Compiler";
#import "Sort";


generate_entity_component_serializers :: (build_context: *Build_Context) -> string {
	builder: String_Builder;
	/*
	print_to_builder(*builder, "\n");
	print_to_builder(*builder, "// Serializer for Entity Components\n");
	print_to_builder(*builder, "serialize_component :: (dest: *[..]u8, src: *$T, offset: *s64){\n");
		print_to_builder(*builder, "\tif type_of(<<src) == {\n");
		for component: comp_names {
			no_ser, _ := array_find(component.notes, "@no_serialize");
			if no_ser {
				continue;
			}
			print_to_builder(*builder, "\t\tcase %; {\n", component.name);
				print_to_builder(*builder, "\t\t\tcast_component : *% = xx,no_check src;\n", component.name);
				for *member: component.members {
					if member.flags & Type_Info_Struct_Member.Flags.CONSTANT || member.flags & Type_Info_Struct_Member.Flags.AS {
						continue; // using #as will have entity_component as member, we don't want that
					}
					print_to_builder(*builder, "\t\t\tserialize_to_buffer(dest, *cast_component.%, offset, %);\n", member.name, member.type.runtime_size);
				}
			print_to_builder(*builder, "\t\t}\n");
		}
		print_to_builder(*builder, "\t}\n");
	print_to_builder(*builder, "}\n");
	print_to_builder(*builder, "\n");
	print_to_builder(*builder, "// Deserializer for Entity Components\n");
	print_to_builder(*builder, "deserialize_component :: (dest: *$T, src: []u8, offset: *s64){\n");
		print_to_builder(*builder, "\tif type_of(<<dest) == {\n");
		for component: comp_names {
			print_to_builder(*builder, "\t\tcase %; {\n", component.name);
				print_to_builder(*builder, "\t\t\tcast_component : *% = xx,no_check dest;\n", component.name);
				for *member: component.members {
					if member.flags & Type_Info_Struct_Member.Flags.CONSTANT || member.flags & Type_Info_Struct_Member.Flags.AS {
						continue; // using #as will have entity_component as member, we don't want that
					}
					print_to_builder(*builder, "\t\t\tdeserialize_from_buffer(*cast_component.%, src, offset, %);\n", member.name, member.type.runtime_size);
				}
			print_to_builder(*builder, "\t\t}\n");
		}
		print_to_builder(*builder, "\t}\n");

	print_to_builder(*builder, "}\n");
	print_to_builder(*builder, "\n");
	
	Note_Data :: struct {
		note : string;
		type_struct : *Type_Info_Struct_Member;
	}
	Note_Level :: struct {
		level : u8;
		size : u32;
	}
	print_to_builder(*builder, "// Size of entity component at given intel level for deserialization (see: x in archetype gen file)\n");
	print_to_builder(*builder, "size_of_component :: (type: Type, intel_level: u8 = INTEL_LEVEL_MAX) -> u32 {\n");
		print_to_builder(*builder, "\tif type == {\n");
		for component: comp_names {
			for note: component.notes {
				if note == "no_ser" { // TODO: doesn't work, why? No notes in component? But there are?
					continue component;
				}
			}
			print_to_builder(*builder, "\t\tcase %; {\n", component.name);
			
			found_notes : [..]Note_Data;
			component_size : u32;
			defer free(found_notes.data);
				for *member: component.members {
					if member.name == "entity_component" {
						continue; // using #as will have entity_component as member, we don't want that
					}
					for note: member.notes {
						for *INTEL_NOTES {
							if <<it == note {
								array_add(*found_notes, .{note, member});
							}
						}
					}
				}
				if !found_notes.count {
						print_to_builder(*builder, "\t\t\treturn %;\n", component.runtime_size);
						print_to_builder(*builder, "\t\t}\n");
						continue component;
				}
				print_to_builder(*builder, "\t\t\tif intel_level == INTEL_LEVEL_MAX {return %;};\n", component.runtime_size);
				note_levels : [..]Note_Level;
				for found_notes {
					found, note, level_string := split_from_right(it.note, "_");
					assert(found, tprint("Attempted to split the intel note but no _ separator was found in note %", it));
					level, success := parse_int(*level_string, u8);
					assert(success, tprint("Attempted to parse to string but failed in %", level_string));
					already_exists := false;
					for *note_level: note_levels {
						if level == note_level.level { // If there already is a level of the same intel level, just increment size
							note_level.size += xx it.type_struct.type.runtime_size;
							already_exists = true;
            				break;
						}
					}
					if !already_exists {
						array_add(*note_levels, Note_Level.{level, xx it.type_struct.type.runtime_size});
					}
					
				}
				quick_sort(note_levels, (x) => x.level);
				for note_levels {
					print_to_builder(*builder, "\t\t\tif intel_level >= % {return %;};\n", it.level, it.size);
				}
			print_to_builder(*builder, "\t\t}\n");
		}
		print_to_builder(*builder, "\t}\n");
	print_to_builder(*builder, "\treturn 0;\n");
	print_to_builder(*builder, "}\n");*/
	return builder_to_string(*builder);	
}

generate_entity_component_switches :: (build_context: *Build_Context) -> string {
	builder: String_Builder;
	
	print_to_builder(*builder, "\n");
	print_to_builder(*builder, "// Get the component bit mask index for the given Type\n");
	print_to_builder(*builder, "get_entity_component_bit_index :: (t: Type) -> u32 {\n");
	print_to_builder(*builder, "\tif t == {\n");

	for build_context.entity_components {
		print_to_builder(*builder, "\t\tcase %; return %;\n", it.name, it_index);
	}

	print_to_builder(*builder, "\t\tcase; return 0;\n");
	print_to_builder(*builder, "\t}\n");
	print_to_builder(*builder, "}\n");

	print_to_builder(*builder, "\n");
	print_to_builder(*builder, "// Get the entity component size \n");
	print_to_builder(*builder, "get_entity_component_size :: (T: Type) -> u32 {\n");
	print_to_builder(*builder, "\tif T == {\n");
	
	for build_context.entity_components {
		print_to_builder(*builder, "\t\tcase %; return %;\n", it.name, it.runtime_size);
	}

	print_to_builder(*builder, "\t\tcase; return 0;\n");
	print_to_builder(*builder, "\t}\n");
	print_to_builder(*builder, "}\n");


	return builder_to_string(*builder);
}

generate_archetype_component_switches :: (build_context: *Build_Context) -> string {
	builder: String_Builder;

	print_to_builder(*builder, "\n");
	print_to_builder(*builder, "// Get the archetype component index for the given type\n");
	print_to_builder(*builder, "get_archetype_component_bit_index :: (t: Type) -> u32 {\n");
	print_to_builder(*builder, "\tif t == {\n");

	for build_context.archetype_components {
		print_to_builder(*builder, "\t\tcase %; return %;\n", it.name, it_index);
	}

	print_to_builder(*builder, "\t\tcase; return 0;\n");
	print_to_builder(*builder, "\t}\n");
	print_to_builder(*builder, "}\n");

	print_to_builder(*builder, "\n");
	print_to_builder(*builder, "// Get the archetype component size \n");
	print_to_builder(*builder, "get_archetype_component_size :: (T: Type) -> u32 {\n");
	print_to_builder(*builder, "\tif T == {\n");

	for build_context.archetype_components {
		print_to_builder(*builder, "\t\tcase %; return %;\n", it.name, it.runtime_size);
	}

	print_to_builder(*builder, "\t\tcase; return 0;\n");
	print_to_builder(*builder, "\t}\n");
	print_to_builder(*builder, "}\n");

	return builder_to_string(*builder);
}