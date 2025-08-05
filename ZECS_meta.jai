#import "Basic";
#import "Compiler";
#import "Sort";

Archetype_Build_Metadata :: struct {
	name 				: string;

	entity_components	: [..]string;
	arch_components		: [..]string;
	tags				: [..]string;
	
}

get_arch_names :: (arch_metadata: []Archetype_Build_Metadata) -> [..]string{
	name_array : [..]string;
	
	for arch_metadata{
		array_add(*name_array, it.name);
	}
	return name_array;
}

generate_ZECS_constants :: (entity_comp_count: s64, arch_comp_count: s64, tag_count: s64) -> string {
	builder: String_Builder;

	print_to_builder(*builder, "// ZECS Constants\n");
	print_to_builder(*builder, "MAX_ENTITY_COMPONENTS :: %;\n", entity_comp_count);
	print_to_builder(*builder, "MAX_ARCH_COMPONENTS :: %;\n", arch_comp_count);
	print_to_builder(*builder, "MAX_TAGS :: %;\n", tag_count);
	print_to_builder(*builder, "\n");

	return builder_to_string(*builder);	
}

generate_archetype_initializers :: (arch_const_names: []string) -> string {
	builder: String_Builder;
	/*
	quick_sort(arch_const_names, compare_strings);

	print_to_builder(*builder, "\n");
	print_to_builder(*builder, "// Archetype Initializers \n");

	for arch_const_names {
		print_to_builder(*builder, "init_arch_% :: (storage: *Archetype_Storage, entity_index: u32) {\n", it);  
		print_to_builder(*builder, "", it, it_index);  

	}
	print_to_builder(*builder, "\n");*/

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

generate_archetype_switch :: (arch_names: []string, fn_name_arch_switch: string) -> string {
	builder: String_Builder;

	quick_sort(arch_names, compare_strings);

	if(fn_name_arch_switch != "") {	
		print_to_builder(*builder, "\n");
		print_to_builder(*builder, "// Get the index for the given Type\n");
		print_to_builder(*builder, "% :: (t: Type) -> u16 {\n", fn_name_arch_switch);
		print_to_builder(*builder, "\tif t == {\n");

		for arch_names {
			print_to_builder(*builder, "\t\tcase type_of(%); return %;\n", it, it_index);
		}

		print_to_builder(*builder, "\t\tcase; return 0;\n");
		print_to_builder(*builder, "\t}\n");
		print_to_builder(*builder, "}\n");
	}

	return builder_to_string(*builder);
}

generate_archetype_initializer_switch :: (archetypes_metadata: []Archetype_Build_Metadata, fn_name_init_switch: string) -> string {

	builder: String_Builder;

	print_to_builder(*builder, "\n");
	print_to_builder(*builder, "// Initializer getter for archetypes\n");
	print_to_builder(*builder, "% :: (t: Type) -> u16 {\n", fn_name_init_switch);
	print_to_builder(*builder, "\tif t == {\n");

	for archetypes_metadata {
	
		print_to_builder(*builder, "\t\tcase type_of(%); return %;\n", it.name, 0);

	}

	print_to_builder(*builder, "\t\tcase; return 0;\n");
	print_to_builder(*builder, "\t}\n");
	print_to_builder(*builder, "}\n");

	return builder_to_string(*builder);
}

generate_archetype_initializers :: (archetypes_metadata: []Archetype_Build_Metadata) -> string {

	// Should we sort these? 
	builder: String_Builder;

	for arch: archetypes_metadata {
		print_to_builder(*builder, "\n");
		print_to_builder(*builder, "// Entity initializer for %\n", arch.name);

		print_to_builder(*builder, "Initializer_% :: (as: *Archetype_Storage, idx: u32) {\n", arch.name);
		
		for comp_name: arch.entity_components {
			comp_idx_expr := sprint("get_entity_component_index(%)", comp_name);
			print_to_builder(*builder, "\t%_ptr := cast(*%) (as.entity_components[%].data.data + idx * as.entity_components[%].stride);\n", comp_name, comp_name, comp_idx_expr, comp_idx_expr);
		}
		//pos_ptr := cast(*Position)(storage.entity_components[0].data + entity_index * storage.entity_components[0].stride);



		print_to_builder(*builder, "}");
	}

	return builder_to_string(*builder);
}