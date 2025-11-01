#import "Basic";
//#load "generated/ZECS_archetypes_gen.jai";

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
		print_to_builder(*builder, "\tstorage : *Archetype_Storage;\n");
		print_to_builder(*builder, "\t`generations : []u16;\n");
		print_to_builder(*builder, "\t`entity_count : s64;\n");
		print_to_builder(*builder, "\t`archetype_index : u16;\n");
		print_to_builder(*builder, "\t`alive_mask : *Bit_Field(MAX_ENTITIES_PER_ARCHETYPE);\n");

		for e_c: query.entity_components {
			comp_type := get_entity_component_type(e_c);
			print_to_builder(*builder, "\t`%_array :[]%;\n", to_lower_copy(e_c), comp_type); 
		}

		for arch_index: matching_archetypes {
			print_to_builder(*builder, "\tstorage = *world.world_archetypes[%];\n", arch_index);
			print_to_builder(*builder, "\t{\n");
			print_to_builder(*builder, "\t\tif storage.initialized && storage.num_entities != 0 {\n");
				print_to_builder(*builder, "\n");
				for e_c: query.entity_components {
					comp_type := get_entity_component_type(e_c);
					print_to_builder(*builder, "\t\t\t`%_array = array_view(%, *storage.entity_components[%], storage.num_entities);\n", to_lower_copy(e_c), comp_type, get_entity_component_index(get_archetype(arch_index),comp_type)); 
				}
				print_to_builder(*builder, "\n");
				for a_c: query.archetype_components {
					comp_type := get_archetype_component_type(a_c);
					print_to_builder(*builder, "\t\t\t`% = cast,no_check(*%)storage.archetype_components[%];\n", to_lower_copy(a_c), comp_type, it_index);
				}
				print_to_builder(*builder, "\n");

				print_to_builder(*builder, "\t\t\t`generations = array_view_dynamic(storage.generations, storage.generations.count);\n");
				print_to_builder(*builder, "\t\t\t`entity_count = storage.num_entities;\n");
				print_to_builder(*builder, "\t\t\t`archetype_index  = %;\n", arch_index);
			
				print_to_builder(*builder, "\t\t\t`alive_mask  = *storage.alive_mask;\n");

				print_to_builder(*builder, "\n");
				print_to_builder(*builder, "\t\t\t#insert body;\n");
				print_to_builder(*builder, "\t\t}\n");
			print_to_builder(*builder, "\t}\n");
			print_to_builder(*builder, "\n");
		}
		
		print_to_builder(*builder, "}\n");
	}
    return builder_to_string(*builder);
}