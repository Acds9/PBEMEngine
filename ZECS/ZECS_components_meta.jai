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

generate_component_switch :: (comp_names: []string, fn_name_type_idx: string, fn_name_idx_type: string, fn_name_type_size: string) -> string {
	builder: String_Builder;

	quick_sort(comp_names, compare_strings);

	if(fn_name_type_idx != "")
	{
		print_to_builder(*builder, "\n");
		print_to_builder(*builder, "// Get the component storage index for the given Type\n");
		print_to_builder(*builder, "% :: (t: Type) -> u32 {\n", fn_name_type_idx);
		print_to_builder(*builder, "\tif t == {\n");

		for comp_names {
			print_to_builder(*builder, "\t\tcase %; return %;\n", it, it_index);
		}

		print_to_builder(*builder, "\t\tcase; return 0;\n");
		print_to_builder(*builder, "\t}\n");
		print_to_builder(*builder, "}\n");
	}
	
	if(fn_name_idx_type != "")
	{
		print_to_builder(*builder, "\n");
		print_to_builder(*builder, "// Get the component Type for the given index\n");
		print_to_builder(*builder, "% :: (idx: u32) -> Type {\n", fn_name_idx_type);
		print_to_builder(*builder, "\tif idx == {\n");
	
		for comp_names {
			print_to_builder(*builder, "\t\tcase %; return %;\n", it_index, it);
		}

		print_to_builder(*builder, "\t\tcase; return Type;\n");
		print_to_builder(*builder, "\t}\n");
		print_to_builder(*builder, "}\n");
	}

	if(fn_name_type_size != "")
	{
		print_to_builder(*builder, "\n");
		print_to_builder(*builder, "// Get the component size for the given Type\n");
		print_to_builder(*builder, "% :: (T: Type) -> u32 {\n", fn_name_type_size);
		print_to_builder(*builder, "\tif T == {\n");
	
		for comp_names {
			print_to_builder(*builder, "\t\tcase %; return size_of(%);\n", it, it);
		}

		print_to_builder(*builder, "\t\tcase; return 0;\n");
		print_to_builder(*builder, "\t}\n");
		print_to_builder(*builder, "}\n");
	}

	return builder_to_string(*builder);
}

generate_string_to_entity_comp_type :: (comp_names: []string) -> string {
	builder: String_Builder;

	quick_sort(comp_names, compare_strings);

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

	return builder_to_string(*builder);
}

generate_string_to_arch_comp_type :: (comp_names: []string) -> string {
	builder: String_Builder;

	quick_sort(comp_names, compare_strings);

	print_to_builder(*builder, "\n");
	print_to_builder(*builder, "// Get the arch component Type from a string name\n");
	print_to_builder(*builder, "get_arch_component_type :: (name: string) -> Type {\n");
	print_to_builder(*builder, "\tif name == {\n");

	for comp_names {
		print_to_builder(*builder, "\t\tcase \"%\"; return %;\n", it, it);
	}
	print_to_builder(*builder, "\t\tcase; return Position;\n");
	print_to_builder(*builder, "\t}\n");
	print_to_builder(*builder, "}\n");

	return builder_to_string(*builder);
}