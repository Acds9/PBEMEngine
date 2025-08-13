#import "Basic";
//#load "generated/ZECS_archetypes_gen.jai";

// TODO: we use the metadata, maybe we should use the database instead so it's single source of truth?
generate_queries :: (archetypes: []Archetype_Build_Metadata, queries: []Query_Build_Metadata) -> string {
	
	builder: String_Builder;

	// First we find the archetypes that match
	matching_archetypes : [..]Archetype_Build_Metadata;
	for query: queries {
		print("Query:%\n", query);
		for arch: archetypes {
			// Currently we can't really use bitmasks due to the different formats (queries don't have them)
			// TODO: if not even queries use bitmasks, why are we even using them?
			for query.entity_components {
				if !(array_find(arch.entity_components, it)) break arch;
			}
			for query.archetype_components {
				if !(array_find(arch.arch_components, it)) break arch;
			}
			if (query.tags &arch.tags) != query.tags break arch; // is query tags NOT a subset of arch tags
			array_add(*matching_archetypes, arch);
		}
		if !matching_archetypes break query;

		matching_archetype_indices : [..]u16;
		for arch: matching_archetypes {
			arch_type := get_arch_type(arch.name);
			array_add(*matching_archetype_indices, get_arch_index(arch_type));
		}

		print_to_builder(*builder, "\n// Query Executor for %\n", query.name);
		print_to_builder(*builder, "execute_% :: (world: *ZWorld, $body: Code) #expand {\n", query.name);

			print_to_builder(*builder, "\tMATCHING_ARCHETYPES		:: u16.%;\n", matching_archetype_indices);
			print_to_builder(*builder, "\tfor arch_idx: MATCHING_ARCHETYPES {\n");
				
			print_to_builder(*builder, "\t\tstorage := *world.world_archetypes[arch_idx];\n");
			print_to_builder(*builder, "\t\tif !storage.initialized continue;\n");
			print_to_builder(*builder, "\t\tif storage.num_entities == 0 continue;\n");
			print_to_builder(*builder, "\n");
			for e_c: query.entity_components {
				comp_type := get_entity_component_type(e_c);
				print_to_builder(*builder, "\t\t`%_array := array_view(%, *storage.entity_components[%], storage.num_entities);\n", to_lower_copy(e_c), comp_type, it_index);
			}
			print_to_builder(*builder, "\n");
			for a_c: query.archetype_components {
				comp_type := get_archetype_component_type(a_c);
				print_to_builder(*builder, "\t\t`% := cast,no_check(*%)storage.archetype_components[%];\n", to_lower_copy(a_c), comp_type, it_index);
			}
			print_to_builder(*builder, "\n");

			print_to_builder(*builder, "\t\t`generations := array_view_dynamic(storage.generations, storage.generations.count);\n");
			print_to_builder(*builder, "\t\t`entity_count := storage.num_entities;\n");
			print_to_builder(*builder, "\t\t`archetype_index  := arch_idx;\n");
			
			print_to_builder(*builder, "\t\t`alive_mask  := *storage.alive_mask;\n");

			print_to_builder(*builder, "\t\n");
			print_to_builder(*builder, "\t\t#insert body;\n");
			print_to_builder(*builder, "\t\n");

			print_to_builder(*builder, "\t}\n");
		
		print_to_builder(*builder, "}\n");
	}
    return builder_to_string(*builder);
}