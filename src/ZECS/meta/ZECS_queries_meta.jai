#import "Basic";

// Mirror of Query_Flags from ZECS_queries.jai, make sure to keep them synced
QUERY_FLAG_NON_PARALLEL    :: 1;
QUERY_FLAG_ATOMIC_COUNTER  :: 2;
QUERY_FLAG_RENDERING       :: 4;

generate_queries :: (ctx: *Build_Context) -> string {
	builder: String_Builder;
	queries := ctx.queries;

	print_to_builder(*builder, "\n// Atomic query counters for various uses\n");

	atomic_counters_num : u32;
	for *query: queries {
		if query.options & QUERY_FLAG_ATOMIC_COUNTER {
			query.counter_index = atomic_counters_num;
			atomic_counters_num += 1;
		}
	}
	print_to_builder(*builder, "query_counters : [%]u32;\n", atomic_counters_num);
	
	for *query: queries {
		query_index := it_index;
		// First we find the archetypes that match
		matching_archetypes : [..]u16;
		for *archetype: ctx.archetypes {
			archetype_index : u16 = xx it_index;
			for query.entity_components {
				if !(array_find(archetype.entity_components, it)) continue archetype;
			}
			for query.archetype_components {
				if !(array_find(archetype.archetype_components, it)) continue archetype;
			}
			if (query.tags &cast,no_check(u64)archetype.tags) != query.tags continue archetype; // is query tags NOT a subset of arch tags
			array_add(*matching_archetypes, archetype_index);
		}
		if !matching_archetypes continue query;
		
		print_to_builder(*builder, "\n// Query Executor for %\n", query.type_data.name);
		print_to_builder(*builder, "execute_% :: (world: *ZWorld, $body: Code) #expand {\n", query.type_data.name); 
	
		print_to_builder(*builder, "\tif !(%.WORLD_TYPES & world.type) {\n", query.type_data.name);
			print_to_builder(*builder, "\t\tprint(\"WARNING: Attempted to run % in a world that does not match its types (its types are: \%, but world type is: \%), aborting\\n\", %.WORLD_TYPES, world.type);\n", query.type_data.name, query.type_data.name);
			print_to_builder(*builder, "\t\treturn;\n");
		print_to_builder(*builder, "\t}\n");
		print_to_builder(*builder, "\n");

		print_to_builder(*builder, "\tstorage 			: *Archetype_Storage;\n");
		print_to_builder(*builder, "\tgenerations 		: []u16;\n"); // TODO: maybe prefix all query data with query_?
		print_to_builder(*builder, "\t`query_entity_count : u32;\n");
		print_to_builder(*builder, "\t`current_entity : ZEntity;\n");
		print_to_builder(*builder, "\t`query_archetype_index : u16;\n");
		print_to_builder(*builder, "\talive_mask 		: *Bit_Field(MAX_ENTITIES_PER_ARCHETYPE);\n");
		print_to_builder(*builder, "\t`iteration_idx : u32;\n");

		print_to_builder(*builder, "\n");
		if query.options & QUERY_FLAG_ATOMIC_COUNTER {
			print_to_builder(*builder, "\tif context.thread_index == 0 {\n");
				print_to_builder(*builder, "\t\tatomic_write(*query_counters[%], 0);\n", query.counter_index);
			print_to_builder(*builder, "\t}\n");
			print_to_builder(*builder, "\tbarrier_wait(context.lane_barrier);\n");
			print_to_builder(*builder, "\n");
		}
		print_to_builder(*builder, "\t`query_counter : u32;\n");
		print_to_builder(*builder, "\n");
		print_to_builder(*builder, "\n");
		for e_c: query.entity_components {
			comp_type := get_type(e_c);
			print_to_builder(*builder, "\t%_array 		:[]%;\n", to_lower_copy(e_c.name), comp_type); 
		}
		print_to_builder(*builder, "\n");
		for e_c: query.entity_components {
			comp_type := get_type(e_c);
			print_to_builder(*builder, "\t`% 			: *%;\n", to_lower_copy(e_c.name), comp_type); 
		}
		print_to_builder(*builder, "\n");
		for a_c: query.archetype_components {
			comp_type := get_type(a_c);
			print_to_builder(*builder, "\t`% 			: *%;\n", to_lower_copy(a_c.name), comp_type); 
		}
		print_to_builder(*builder, "\n");

		for arch_index: matching_archetypes {
			print_to_builder(*builder, "\tstorage = *world.world_archetypes[%];\n", arch_index);
			print_to_builder(*builder, "\t{\n");
			print_to_builder(*builder, "\t\tif storage.initialized && storage.num_entities != 0 {\n");
				for e_c: query.entity_components {
					found, component_index := array_find(build_context.archetypes[arch_index].entity_components, e_c);
					assert(found, "ERROR: Could not find component in build context data");
					print_to_builder(*builder, "\t\t\t%_array = array_view(%, *storage.entity_components[%], storage.num_entities);\n", to_lower_copy(e_c.name), get_type(e_c), component_index); 
				}
				print_to_builder(*builder, "\n");
				for a_c: query.archetype_components {
					comp_type := get_type(a_c);
					print_to_builder(*builder, "\t\t\t% = cast,no_check(*%)storage.archetype_components[%];\n", to_lower_copy(a_c.name), get_type(a_c), it_index);
				}
				print_to_builder(*builder, "\n");
				print_to_builder(*builder, "\t\t\tquery_entity_count = storage.num_entities;\n");
				if query.options & QUERY_FLAG_NON_PARALLEL {
					print_to_builder(*builder, "\t\t\tstart : u32 = 0;\n");
					print_to_builder(*builder, "\t\t\tend : u32 = query_entity_count;\n");
				} else {
					print_to_builder(*builder, "\t\t\tstart, end := lane_range(query_entity_count);\n");
				}
				print_to_builder(*builder, "\t\t\tgenerations = storage.generations;\n");
				print_to_builder(*builder, "\n");
				print_to_builder(*builder, "\t\t\tfor idx: start..end {\n");
					print_to_builder(*builder, "\t\t\t\titeration_idx = idx;\n");
					print_to_builder(*builder, "\t\t\t\tif !entity_is_alive(idx, storage) {\n");
					print_to_builder(*builder, "\t\t\t\t\t continue;\n");
					print_to_builder(*builder, "\t\t\t\t}\n");
					if query.options & QUERY_FLAG_ATOMIC_COUNTER {
						print_to_builder(*builder, "\t\t\t\tquery_counter = atomic_add(*query_counters[%], 1);\n", query.counter_index);
					}
					print_to_builder(*builder, "\t\t\t\tcurrent_entity = .{idx, generations[idx], %};\n", arch_index);
					for e_c: query.entity_components {
						comp_type := get_type(e_c);
						print_to_builder(*builder, "\t\t\t\t% = *%_array[idx];\n", to_lower_copy(e_c.name), to_lower_copy(e_c.name)); 
					}
					print_to_builder(*builder, "\t\t\t\t#insert body;\n");
					print_to_builder(*builder, "\t\t\t}\n");
				print_to_builder(*builder, "\t\t}\n");
			print_to_builder(*builder, "\t}\n");
		}
		if query.options & QUERY_FLAG_ATOMIC_COUNTER {
			print_to_builder(*builder, "\tbarrier_wait(context.lane_barrier);\n");
		}
		print_to_builder(*builder, "}\n");
	}
    return builder_to_string(*builder);
}