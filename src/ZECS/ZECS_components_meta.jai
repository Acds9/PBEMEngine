#import "Basic";
#import "Compiler";
#import "Sort";

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
	print_to_builder(*builder, "serialize_component :: (entity_component: *$T, out: *[..]u8){\n");
		print_to_builder(*builder, "\tif type_of(<<entity_component) == {\n");
		for component: comp_names {
			print_to_builder(*builder, "\t\tcase %; {\n", component.name);
				print_to_builder(*builder, "\t\t\tcast_component : *% = xx,no_check entity_component;\n", component.name);
				for member: component.members {
					if member.flags & Type_Info_Struct_Member.Flags.CONSTANT || member.flags & Type_Info_Struct_Member.Flags.AS {
						continue; // using #as will have entity_component as member, we don't want that
					}
					print_to_builder(*builder, "\t\t\tserialize_to_buffer(out, *cast_component.%, %);\n", member.name, member.type.runtime_size);
				}
			print_to_builder(*builder, "\t\t}\n");
		}
		print_to_builder(*builder, "\t}\n");
	print_to_builder(*builder, "}\n");
	print_to_builder(*builder, "\n");
	print_to_builder(*builder, "// Deserializer for Entity Components\n");
	print_to_builder(*builder, "deserialize_component :: (entity_component: *$T, out: *[..]u8, offset: *s64){\n");
		print_to_builder(*builder, "\tif type_of(<<entity_component) == {\n");
		for component: comp_names {
			print_to_builder(*builder, "\t\tcase %; {\n", component.name);
				for member: component.members {
					if member.name == "entity_component" {
						continue; // using #as will have entity_component as member, we don't want that
					}
					print_to_builder(*builder, "\t\t\tdeserialize_from_buffer(out, *entity_component.%, %, offset);\n", member.name, member.type.runtime_size);
				}
			print_to_builder(*builder, "\t\t}\n");
		}
		print_to_builder(*builder, "\t}\n");
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