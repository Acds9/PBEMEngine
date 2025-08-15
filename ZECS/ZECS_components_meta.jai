#import "Basic";
#import "Compiler";
#import "Sort";

generate_ZECS_constants :: (entity_comp_count: s64, arch_comp_count: s64, tag_count: s64) -> string {
	builder: String_Builder;

	print_to_builder(*builder, "// ZECS Constants\n");
	print_to_builder(*builder, "MAX_ENTITY_COMPONENTS :: %;\n", entity_comp_count);
	print_to_builder(*builder, "MAX_ARCH_COMPONENTS :: %;\n", arch_comp_count);
	print_to_builder(*builder, "MAX_TAGS :: %;\n", tag_count);
	print_to_builder(*builder, "\n");

	return builder_to_string(*builder);	
}

generate_entity_component_switches :: (comp_names: []string) -> string {
	builder: String_Builder;

	print_to_builder(*builder, "\n");
	print_to_builder(*builder, "// Get the component bit mask index for the given Type\n");
	print_to_builder(*builder, "get_entity_component_bit_index :: (t: Type) -> u32 {\n");
	print_to_builder(*builder, "\tif t == {\n");

	for comp_names {
		print_to_builder(*builder, "\t\tcase %; return %;\n", it, it_index);
	}

	print_to_builder(*builder, "\t\tcase; return 0;\n");
	print_to_builder(*builder, "\t}\n");
	print_to_builder(*builder, "}\n");
	
	print_to_builder(*builder, "\n");
	print_to_builder(*builder, "// Get the entity component Type for the given bit index\n");
	print_to_builder(*builder, "get_entity_component_bit_type :: (idx: u32) -> Type {\n");
	print_to_builder(*builder, "\tif idx == {\n");
	
	for comp_names {
		print_to_builder(*builder, "\t\tcase %; return %;\n", it_index, it);
	}

	print_to_builder(*builder, "\t\tcase; return Type;\n");
	print_to_builder(*builder, "\t}\n");
	print_to_builder(*builder, "}\n");

	
	print_to_builder(*builder, "\n");
	print_to_builder(*builder, "// Get the entity component size \n");
	print_to_builder(*builder, "get_entity_component_size :: (T: Type) -> u32 {\n");
	print_to_builder(*builder, "\tif T == {\n");
	
	for comp_names {
		print_to_builder(*builder, "\t\tcase %; return size_of(%);\n", it, it);
	}

	print_to_builder(*builder, "\t\tcase; return 0;\n");
	print_to_builder(*builder, "\t}\n");
	print_to_builder(*builder, "}\n");


	return builder_to_string(*builder);
}

generate_archetype_component_switches :: (comp_names: []string) -> string {
	builder: String_Builder;

	print_to_builder(*builder, "\n");
	print_to_builder(*builder, "// Get the archetype component Type for the given bit index\n");
	print_to_builder(*builder, "get_archetype_component_bit_type :: (idx: u32) -> Type {\n");
	print_to_builder(*builder, "\tif idx == {\n");
	
	for comp_names {
		print_to_builder(*builder, "\t\tcase %; return %;\n", it_index, it);
	}

	print_to_builder(*builder, "\t\tcase; return Type;\n");
	print_to_builder(*builder, "\t}\n");
	print_to_builder(*builder, "}\n");


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

generate_string_to_entity_comp_type :: (comp_names: []string) -> string {
	builder: String_Builder;

	print_to_builder(*builder, "\n");
	print_to_builder(*builder, "// Get the entity_component Type from a string name\n");
	print_to_builder(*builder, "get_entity_component_type :: (name: string) -> Type {\n");
	print_to_builder(*builder, "\tif name == {\n");

	for comp_names {
		print_to_builder(*builder, "\t\tcase \"%\"; return %;\n", it, it);
	}
	print_to_builder(*builder, "\t\tcase; return Position;\n");
	print_to_builder(*builder, "\t}\n");
	print_to_builder(*builder, "}\n");

	print_to_builder(*builder, "\n");
	print_to_builder(*builder, "// Get the entity_component string from a Type\n");
	print_to_builder(*builder, "get_entity_component_string :: (t: Type) -> string {\n");
	print_to_builder(*builder, "\tif t == {\n");

	for comp_names {
		print_to_builder(*builder, "\t\tcase %; return \"%\";\n", it, it);
	}
	print_to_builder(*builder, "\t\tcase; return \"Error\";\n");
	print_to_builder(*builder, "\t}\n");
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