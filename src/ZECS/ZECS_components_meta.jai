#import "Basic";
#import "Compiler";
#import "Sort";
#load "H:/PBEMJai/src/intel.jai";

generate_file_loads :: () -> string {
	builder: String_Builder;
   	
	files := string.[
	];
   
   	for files {
		print_to_builder(*builder, "#load \"%\";\n", it);
	}
    return builder_to_string(*builder);
}


generate_ZECS_constants :: (entity_comp_count: s64, arch_comp_count: s64, tag_count: s64) -> string {
	builder: String_Builder;

	print_to_builder(*builder, "// ZECS Constants\n");
	print_to_builder(*builder, "MAX_ENTITY_COMPONENTS :: %;\n", entity_comp_count);
	print_to_builder(*builder, "MAX_ARCH_COMPONENTS :: %;\n", arch_comp_count);
	print_to_builder(*builder, "MAX_TAGS :: %;\n", tag_count);
	print_to_builder(*builder, "MAX_ARCHETYPES :: %;\n", 128); // TODO: need to generate this
	print_to_builder(*builder, "\n");

	return builder_to_string(*builder);	
}

generate_entity_component_serializers :: (comp_names: []*Type_Info_Struct) -> string {
	builder: String_Builder;

	print_to_builder(*builder, "\n");
	print_to_builder(*builder, "// Serializer for Entity Components\n");
	print_to_builder(*builder, "serialize_component :: (dest: *[..]u8, src: *$T, intel_level: u8, offset: *s64){\n");
		print_to_builder(*builder, "\tif type_of(<<src) == {\n");
		for component: comp_names {
			no_ser, _ := array_find(component.notes, "@no_ser");
			if no_ser {
				continue;
			}
			print_to_builder(*builder, "\t\tcase %; {\n", component.name);
				print_to_builder(*builder, "\t\t\tcast_component : *% = xx,no_check src;\n", component.name);
				intel_level_members : [..]Gen_Intel_Level_Members;
				get_struct_intel_level_members(component, *intel_level_members);
				for *level: intel_level_members {
					print_to_builder(*builder, "\t\t\tif intel_level >= % {\n", level.level);
						for level.members {
							print_to_builder(*builder, "\t\t\t\tserialize_to_buffer(dest, *cast_component.%, offset, %);\n", it.name, it.type.runtime_size);
						}
					print_to_builder(*builder, "\t\t\t}\n");	
				}
			print_to_builder(*builder, "\t\t}\n");
		}
		print_to_builder(*builder, "\t}\n");
	print_to_builder(*builder, "}\n");
	print_to_builder(*builder, "\n");
	print_to_builder(*builder, "// Deserializer for Entity Components\n");
	print_to_builder(*builder, "deserialize_component :: (dest: *$T, src: []u8, offset: *s64, intel_level: u8){\n");
		print_to_builder(*builder, "\tif type_of(<<dest) == {\n");
		for component: comp_names {
			print_to_builder(*builder, "\t\tcase %; {\n", component.name);
				intel_level_members : [..]Gen_Intel_Level_Members;
				get_struct_intel_level_members(component, *intel_level_members);
				print_to_builder(*builder, "\t\t\tcast_component : *% = xx,no_check dest;\n", component.name);
				for *level: intel_level_members {
					if level.level > 0 {
						print_to_builder(*builder, "\t\t\tif intel_level >= % {\n", level.level);
					}
						for level.members {
							print_to_builder(*builder, "\t\t\t\tdeserialize_from_buffer(*cast_component.%, src, offset, %);\n", it.name, it.type.runtime_size);
						}
					if level.level > 0 {
						print_to_builder(*builder, "\t\t\t}\n");	
					}
				}
				/*
				for member: component.members {
					if member.name == "entity_component" {
						continue; // using #as will have entity_component as member, we don't want that
					}
					print_to_builder(*builder, "\t\t\tdeserialize_from_buffer(out, *entity_component.%, %, offset);\n", member.name, member.type.runtime_size);
				}*/
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
	print_to_builder(*builder, "}\n");
	return builder_to_string(*builder);	
}

generate_entity_component_switches :: (comp_names: []*Type_Info_Struct) -> string {
	builder: String_Builder;

	print_to_builder(*builder, "\n");
	print_to_builder(*builder, "// Get the component bit mask index for the given Type\n");
	print_to_builder(*builder, "get_entity_component_bit_index :: (t: Type) -> u32 {\n");
	print_to_builder(*builder, "\tif t == {\n");

	for comp_names {
		print_to_builder(*builder, "\t\tcase %; return %;\n", it.name, it_index);
	}

	print_to_builder(*builder, "\t\tcase; return 0;\n");
	print_to_builder(*builder, "\t}\n");
	print_to_builder(*builder, "}\n");

	print_to_builder(*builder, "\n");
	print_to_builder(*builder, "// Get the entity component size \n");
	print_to_builder(*builder, "get_entity_component_size :: (T: Type) -> u32 {\n");
	print_to_builder(*builder, "\tif T == {\n");
	
	for comp_names {
		print_to_builder(*builder, "\t\tcase %; return %;\n", it.name, it.runtime_size);
	}

	print_to_builder(*builder, "\t\tcase; return 0;\n");
	print_to_builder(*builder, "\t}\n");
	print_to_builder(*builder, "}\n");


	return builder_to_string(*builder);
}

generate_archetype_component_switches :: (comp_names: []string) -> string {
	builder: String_Builder;

	print_to_builder(*builder, "\n");
	print_to_builder(*builder, "// Get the archetype component index for the given type\n");
	print_to_builder(*builder, "get_archetype_component_bit_index :: (t: Type) -> u32 {\n");
	print_to_builder(*builder, "\tif t == {\n");
	
	for comp_names {
		print_to_builder(*builder, "\t\tcase %; return %;\n", it, it_index);
	}

	print_to_builder(*builder, "\t\tcase; return 0;\n");
	print_to_builder(*builder, "\t}\n");
	print_to_builder(*builder, "}\n");

	print_to_builder(*builder, "\n");
	print_to_builder(*builder, "// Get the archetype component size \n");
	print_to_builder(*builder, "get_archetype_component_size :: (T: Type) -> u32 {\n");
	print_to_builder(*builder, "\tif T == {\n");
	
	for comp_names {
		print_to_builder(*builder, "\t\tcase %; return size_of(%);\n", it, it);
	}

	print_to_builder(*builder, "\t\tcase; return 0;\n");
	print_to_builder(*builder, "\t}\n");
	print_to_builder(*builder, "}\n");

	return builder_to_string(*builder);
}

generate_string_to_entity_comp_type :: (comp_names: []*Type_Info_Struct) -> string {
	builder: String_Builder;

	print_to_builder(*builder, "\n");
	print_to_builder(*builder, "// Get the entity_component Type from a string name\n");
	print_to_builder(*builder, "get_entity_component_type :: (name: string) -> Type {\n");
	print_to_builder(*builder, "\tif name == {\n");

	for comp_names {
		print_to_builder(*builder, "\t\tcase \"%\"; return %;\n", it.name, it.name);
	}
	print_to_builder(*builder, "\t\tcase; return Position;\n");
	print_to_builder(*builder, "\t}\n");
	print_to_builder(*builder, "}\n");

	print_to_builder(*builder, "\n");
	print_to_builder(*builder, "// Get the entity_component string from a Type\n");
	print_to_builder(*builder, "get_entity_component_string :: (t: Type) -> string {\n");
	print_to_builder(*builder, "\tif t == {\n");

	for comp_names {
		print_to_builder(*builder, "\t\tcase %; return \"%\";\n", it.name, it.name);
	}
	print_to_builder(*builder, "\t\tcase; return \"Error\";\n");
	print_to_builder(*builder, "\t}\n");
	print_to_builder(*builder, "}\n");

	print_to_builder(*builder, "\n");
	print_to_builder(*builder, "// Get the entity_component strings from a Type array\n");
	print_to_builder(*builder, "get_entity_component_strings :: (t: []Type) -> [..]string {\n");

		print_to_builder(*builder, "\tstrings : [..]string;\n");
		print_to_builder(*builder, "\tfor t {\n");

			print_to_builder(*builder, "\t\tarray_add(*strings, get_entity_component_string(it));\n");

		print_to_builder(*builder, "\t}\n");
	print_to_builder(*builder, "\treturn strings;\n");
	print_to_builder(*builder, "}\n");

	print_to_builder(*builder, "\n");
	print_to_builder(*builder, "// Get the archetype component strings from a Type array\n");
	print_to_builder(*builder, "get_archetype_component_strings :: (t: []Type) -> [..]string {\n");
	
		print_to_builder(*builder, "\tstrings : [..]string;\n");
		print_to_builder(*builder, "\tfor t {\n");

			print_to_builder(*builder, "\t\tarray_add(*strings, get_archetype_component_string(it));\n");

		print_to_builder(*builder, "\t}\n");
	print_to_builder(*builder, "\treturn strings;\n");
	print_to_builder(*builder, "}\n");

	return builder_to_string(*builder);
}

generate_string_to_arch_comp_type :: (comp_names: []string) -> string {
	builder: String_Builder;

	print_to_builder(*builder, "\n");
	print_to_builder(*builder, "// Get the arch component Type from a string name\n");
	print_to_builder(*builder, "get_archetype_component_type :: (name: string) -> Type {\n");
	print_to_builder(*builder, "\tif name == {\n");

	for comp_names {
		print_to_builder(*builder, "\t\tcase \"%\"; return %;\n", it, it);
	}
	print_to_builder(*builder, "\t\tcase; return Position;\n");
	print_to_builder(*builder, "\t}\n");
	print_to_builder(*builder, "}\n");

	print_to_builder(*builder, "\n");
	print_to_builder(*builder, "// Get the archetype component string from a Type\n");
	print_to_builder(*builder, "get_archetype_component_string :: (t: Type) -> string {\n");
	print_to_builder(*builder, "\tif t == {\n");

	for comp_names {
		print_to_builder(*builder, "\t\tcase %; return \"%\";\n", it, it);
	}
	print_to_builder(*builder, "\t\tcase; return \"Error\";\n");
	print_to_builder(*builder, "\t}\n");
	print_to_builder(*builder, "}\n");

	return builder_to_string(*builder);
}