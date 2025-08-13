#import "Basic";


generate_observers :: (archetypes: []Archetype_Build_Metadata, observers: []Observer_Build_Metadata) -> string {
	
	builder: String_Builder;

	// First we find the archetypes that match
	matching_archetypes : [..]Archetype_Build_Metadata;
	for observer: observers {
		for arch: archetypes {
			for observer.entity_components {
				if !(array_find(arch.entity_components, it)) break arch;
			}
			for observer.archetype_components {
				if !(array_find(arch.arch_components, it)) break arch;
			}
			if (observer.tags &arch.tags) != observer.tags break arch;
			array_add(*matching_archetypes, arch);
		}
		if !matching_archetypes break observer;

		matching_archetype_indices : [..]u16;
		for arch: matching_archetypes {
			arch_type := get_arch_type(arch.name);
			array_add(*matching_archetype_indices, get_arch_index(arch_type));
		}

		print_to_builder(*builder, "\n// Observer Executor for %\n", observer.name);
		print_to_builder(*builder, "execute_% :: (world: *ZWorld, arch_idx: u16, entities: []ZEntity) {\n", observer.name);
			print_to_builder(*builder, "\tarch_storage := *world.world_archetypes[arch_idx];\n");

			// These are not used right now, we use a function instead of arbitrary code that could access these
			//TODO: if we ever find out how to extract code from a #code block properly without it being a pain in the ass we can return to this and fix it
			/*print_to_builder(*builder, "\tfor entity: entities {\n");
				for e_c: observer.entity_components {
					e_c_idx := get_entity_component_index(get_entity_component_type(e_c));
					print_to_builder(*builder, "\t\t% := *get_entity_component(*arch_storage.entity_components[%], entity.index, %);\n", to_lower_copy(e_c), e_c_idx, e_c);
				}
				for a_c: observer.archetype_components {
					print_to_builder(*builder, "\t\t% := *get_archetype_component(world, arch_idx, %);\n", to_lower_copy(a_c), a_c);
				}

				print_to_builder(*builder, "\t\t%.PROC(entity, arch_idx, world);\n", observer.name);

			print_to_builder(*builder, "\t}\n");*/

		print_to_builder(*builder, "}\n");

		print_to_builder(*builder, "\n// Observer Registerer for %\n", observer.name);
		print_to_builder(*builder, "register_% :: (world: *ZWorld) {\n", observer.name);

			print_to_builder(*builder, "\tMATCHING_ARCHETYPES		:: u16.%;\n", matching_archetype_indices);
			print_to_builder(*builder, "\tfor arch_idx: MATCHING_ARCHETYPES {\n");
				
				print_to_builder(*builder, "\t\tentry := Observer_Entry.{priority = %, proc = execute_%};\n", observer.priority, observer.name);
			
				print_to_builder(*builder, "\t\tarray_add(*world.observer_registry.on_created[arch_idx], entry);\n");

			print_to_builder(*builder, "\t}\n");
		
		print_to_builder(*builder, "}\n");
	}
    return builder_to_string(*builder);
}

// Add the observer registry and flushing and try registering an observer