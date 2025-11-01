#import "Basic";


generate_observers :: (observers: []Observer_Build_Metadata) -> string {
	builder: String_Builder;
	for observer: observers {
			// First we find the archetypes that match
		matching_archetypes : [..]u16;
		for arch: ARCHETYPE_DATABASE {
			arch_entity_comp_strings := get_entity_component_strings(arch.entity_components);
			arch_arch_comp_strings := get_archetype_component_strings(arch.archetype_components);
			for observer.entity_components {
				if !(array_find(arch_entity_comp_strings, it)) continue arch;
			}
			for observer.archetype_components {
				if !(array_find(arch_arch_comp_strings, it)) continue arch;
			}
			if (observer.tags &cast,no_check(u64)arch.tags) != observer.tags continue arch;
			array_add(*matching_archetypes, arch.index);
		}
		if !matching_archetypes continue observer;

		print_to_builder(*builder, "\n// Observer Executor for %\n", observer.name);
		print_to_builder(*builder, "execute_% :: (game_state: *Game_State, entities: []ZEntity) {\n", observer.name);
			print_to_builder(*builder, "\tworld := *game_state.world;\n");
			print_to_builder(*builder, "\tarchetype := entities[0].archetype;\n");
			print_to_builder(*builder, "\tarch_storage := *world.world_archetypes[entities[0].archetype];\n");
			
			print_to_builder(*builder, "\tfor entity: entities {\n");
				for e_c: observer.entity_components {
					print_to_builder(*builder, "\t\t% := *get_entity_component(world, entity, %);\n", to_lower_copy(e_c), e_c);
				}
				for a_c: observer.archetype_components {
					print_to_builder(*builder, "\t\t% := *get_archetype_component(world, get_archetype(archetype), %);\n", to_lower_copy(a_c), a_c);
				}

				print_to_builder(*builder, "\t\t%_Event(entity, game_state);\n", observer.name);

			print_to_builder(*builder, "\t}\n");

		print_to_builder(*builder, "}\n");

		print_to_builder(*builder, "\n// Observer Registerer for %\n", observer.name);
		print_to_builder(*builder, "register_% :: (world: *ZWorld) {\n", observer.name);

			print_to_builder(*builder, "\tMATCHING_ARCHETYPES		:: u16.%;\n", matching_archetypes);
			print_to_builder(*builder, "\tfor arch_idx: MATCHING_ARCHETYPES {\n");
				print_to_builder(*builder, "\t\tentry := Observer_Entry.{priority = %, proc = execute_%};\n", observer.priority, observer.name);
				
				print_to_builder(*builder, "\t\tfor *world.observer_registry.on_created[arch_idx] {\n");
					print_to_builder(*builder, "\t\t\tif it.proc == entry.proc {\n");
						print_to_builder(*builder, "\t\t\t\tprint(\"WARNING: Attempted to register an already registered observer: \%\\n\", entry);\n");
						print_to_builder(*builder, "\t\t\t\treturn;\n");
					print_to_builder(*builder, "\t\t\t}\n");
				print_to_builder(*builder, "\t\t}\n");
			
				print_to_builder(*builder, "\t\tarray_add(*world.observer_registry.on_created[arch_idx], entry);\n");

			print_to_builder(*builder, "\t}\n");
		
		print_to_builder(*builder, "}\n");
	}
	print_to_builder(*builder, "\n// Observer Registration Function\n");
	print_to_builder(*builder, "register_observers :: (world: *ZWorld) {\n");
		for observer: observers {
				print_to_builder(*builder, "\tregister_%(world);\n", observer.name);
		}
	print_to_builder(*builder, "}\n");
    return builder_to_string(*builder);
}

