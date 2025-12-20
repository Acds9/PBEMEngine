#import "Basic";
#load "ZECS_queries.jai";

// TODO: we use the metadata, maybe we should use the database instead so it's single source of truth?
generate_queries :: (queries: []Query_Build_Metadata) -> string {
	
	builder: String_Builder;
	
	for query: queries {
		// First we find the archetypes that match
		matching_archetypes : [..]u16;
		for arch: ARCHETYPE_DATABASE {
			arch_entity_comp_strings := get_entity_component_strings(arch.entity_components);
			arch_arch_comp_strings := get_archetype_component_strings(arch.archetype_components);
			for query.entity_components {
				if !(array_find(arch_entity_comp_strings, it)) continue arch;
			}
			for query.archetype_components {
				if !(array_find(arch_arch_comp_strings, it)) continue arch;
			}
			if (query.tags &cast,no_check(u64)arch.tags) != query.tags continue arch; // is query tags NOT a subset of arch tags
			array_add(*matching_archetypes, arch.index);
		}
		if !matching_archetypes continue query;

		print_to_builder(*builder, "\n// Query Executor for %\n", query.name);
		print_to_builder(*builder, "execute_% :: (world: *ZWorld, $body: Code) #expand {\n", query.name); 
		print_to_builder(*builder, "\tstorage 			: *Archetype_Storage;\n");
		print_to_builder(*builder, "\tgenerations 		: []u16;\n");
		print_to_builder(*builder, "\tentity_count 		: u32;\n");
		print_to_builder(*builder, "\tarchetype_index 	: u16;\n");
		print_to_builder(*builder, "\talive_mask 		: *Bit_Field(MAX_ENTITIES_PER_ARCHETYPE);\n");
		print_to_builder(*builder, "\n");
		print_to_builder(*builder, "\n");
		for e_c: query.entity_components {
			comp_type := get_entity_component_type(e_c);
			print_to_builder(*builder, "\t%_array 		:[]%;\n", to_lower_copy(e_c), comp_type); 
		}
		print_to_builder(*builder, "\n");
		for e_c: query.entity_components {
			comp_type := get_entity_component_type(e_c);
			print_to_builder(*builder, "\t`% 			: *%;\n", to_lower_copy(e_c), comp_type); 
		}
		print_to_builder(*builder, "\n");
		for a_c: query.archetype_components {
			comp_type := get_archetype_component_type(a_c);
			print_to_builder(*builder, "\t`% 			: *%;\n", to_lower_copy(a_c), comp_type); 
		}
		print_to_builder(*builder, "\n");
		for arch_index: matching_archetypes {
			print_to_builder(*builder, "\tstorage = *world.world_archetypes[%];\n", arch_index);
			print_to_builder(*builder, "\t{\n");
			print_to_builder(*builder, "\t\tif storage.initialized && storage.num_entities != 0 {\n");
				for e_c: query.entity_components {
					comp_type := get_entity_component_type(e_c);
					print_to_builder(*builder, "\t\t\t%_array = array_view(%, *storage.entity_components[%], storage.num_entities);\n", to_lower_copy(e_c), comp_type, get_entity_component_index(get_archetype(arch_index),comp_type)); 
				}
				print_to_builder(*builder, "\n");
				for a_c: query.archetype_components {
					comp_type := get_archetype_component_type(a_c);
					print_to_builder(*builder, "\t\t\t% = cast,no_check(*%)storage.archetype_components[%];\n", to_lower_copy(a_c), comp_type, it_index);
				}
				print_to_builder(*builder, "\n");
				print_to_builder(*builder, "\t\t\tentity_count = storage.num_entities;\n");
				if query.options & cast(u32)Query_Flags.NON_PARALLEL {
					print_to_builder(*builder, "\t\t\tstart : u32 = 0;\n");
					print_to_builder(*builder, "\t\t\tend : u32 = entity_count;\n");
				} else {
					print_to_builder(*builder, "\t\t\tstart, end := lane_range(entity_count);\n");
				}
				print_to_builder(*builder, "\n");
				print_to_builder(*builder, "\t\t\tfor idx: start..end {\n");
					print_to_builder(*builder, "\t\t\t\tif !entity_is_alive(idx, storage) {\n");
					print_to_builder(*builder, "\t\t\t\t\t continue;\n");
					print_to_builder(*builder, "\t\t\t\t}\n");
					for e_c: query.entity_components {
						comp_type := get_entity_component_type(e_c);
						print_to_builder(*builder, "\t\t\t\t% = *%_array[idx];\n", to_lower_copy(e_c), to_lower_copy(e_c)); 
					}
					print_to_builder(*builder, "\t\t\t\t#insert body;\n");
					print_to_builder(*builder, "\t\t\t}\n");
				print_to_builder(*builder, "\t\t}\n");
			print_to_builder(*builder, "\t}\n");
		}
		print_to_builder(*builder, "}\n");
	}
    return builder_to_string(*builder);
}