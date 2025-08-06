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

// To get the archetype index for the storage in the world
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

generate_archetype_e_c_storage_mappings :: (archetypes_metadata: []Archetype_Build_Metadata) -> string {
	
	builder: String_Builder;

	print_to_builder(*builder, "\n");

	print_to_builder(*builder, "get_e_c_storage_ptr :: (world: *ZWorld, arch: Type, $T: Type) -> *Entity_Component_Storage {\n");
	print_to_builder(*builder, "\tif arch =={\n");
	for arch: archetypes_metadata {
	
		print_to_builder(*builder, "\t\tcase type_of(%);\n", arch.name);
		print_to_builder(*builder, "\t\t\ta_s := *world.world_archetypes[get_arch_index(%)];\n", arch.name);
		print_to_builder(*builder, "\t\t\tif T =={\n");
		for e_c: arch.entity_components {
			print_to_builder(*builder, "\t\t\t\tcase %; return *a_s.entity_components[%];\n", e_c, it_index);
		}
		print_to_builder(*builder, "\t\t\t\tcase; return null;\n");
		print_to_builder(*builder, "\t\t\t}\n");
	}
	print_to_builder(*builder, "\t\tcase; return null;\n");
	print_to_builder(*builder, "\t}\n");
	print_to_builder(*builder, "}\n");
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