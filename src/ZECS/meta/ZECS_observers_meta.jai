#import "Basic";

OBSERVER_FLAG_RENDERING    	:: 1;
OBSERVER_FLAG_AUTOREGISTER  :: 2;

generate_observers :: (ctx: *Build_Context) -> string {
	builder: String_Builder;
	observers := ctx.observers;
	for *observer: observers {
		observer_index := it_index;
		// First we find the archetypes that match
		matching_archetypes : [..]u16;
		for *archetype: ctx.archetypes {
			archetype_index : u16 = xx it_index;
			for observer.entity_components {
				if !(array_find(archetype.entity_components, it)) continue archetype;
			}
			for observer.archetype_components {
				if !(array_find(archetype.archetype_components, it)) continue archetype;
			}
			if (observer.tags &cast,no_check(u64)archetype.tags) != observer.tags continue archetype;
			array_add(*matching_archetypes, archetype_index);
		}
		if !matching_archetypes continue observer;

		print_to_builder(*builder, "\n// Observer Executor for %\n", observer.type_data.name);
		print_to_builder(*builder, "execute_% :: (game_world: *Game_World, entities: []ZEntity) {\n", observer.type_data.name);

			print_to_builder(*builder, "\tworld := *game_world.world;\n");
			print_to_builder(*builder, "\tarchetype := entities[0].archetype;\n");
			print_to_builder(*builder, "\tarch_storage := *world.world_archetypes[archetype];\n");
			print_to_builder(*builder, "\tmin, max := lane_range(xx,no_check entities.count);\n");
			print_to_builder(*builder, "\tfor min..max {\n");
				print_to_builder(*builder, "\t\tentity := entities[it];\n");
				
				for e_c: observer.entity_components {
					print_to_builder(*builder, "\t\t% := *get_entity_component(world, entity, %);\n", to_lower_copy(e_c.name), e_c.name);
				}
				for a_c: observer.archetype_components {
					print_to_builder(*builder, "\t\t% := *get_archetype_component(world, get_archetype(archetype), %);\n", to_lower_copy(a_c.name), a_c.name);
				}

				print_to_builder(*builder, "\t\t%_Event(entity, game_world);\n", observer.type_data.name);

			print_to_builder(*builder, "\t}\n");

		print_to_builder(*builder, "}\n");

		print_to_builder(*builder, "\n// Observer Registerer for %\n", observer.type_data.name);
		print_to_builder(*builder, "register_% :: (world: *ZWorld) {\n", observer.type_data.name);

			print_to_builder(*builder, "\tMATCHING_ARCHETYPES		:: u16.%;\n", matching_archetypes);
			print_to_builder(*builder, "\tfor arch_idx: MATCHING_ARCHETYPES {\n");
				print_to_builder(*builder, "\t\tentry := Observer_Entry.{priority = %, proc = execute_%};\n", observer.priority, observer.type_data.name);
				
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
		print_to_builder(*builder, "\tif world.type & .MAIN_MENU {\n");
			for observer: observers {
				if !(observer.flags & OBSERVER_FLAG_AUTOREGISTER) {
					continue observer;
				}
				if observer.world_types & BUILD_WORLD_TYPE_MENU {
					print_to_builder(*builder, "\t\tregister_%(world);\n", observer.type_data.name);
				}
			}
		print_to_builder(*builder, "\t}\n");
		print_to_builder(*builder, "\tif world.type & .REPLAY {\n");
			for observer: observers {
				if !(observer.flags & OBSERVER_FLAG_AUTOREGISTER) {
					continue observer;
				}
				if observer.world_types & BUILD_WORLD_TYPE_REPLAY {
					print_to_builder(*builder, "\t\tregister_%(world);\n", observer.type_data.name);
				}
			}
		print_to_builder(*builder, "\t}\n");
		print_to_builder(*builder, "\tif world.type & .SIMULATION {\n");
			for observer: observers {
				if !(observer.flags & OBSERVER_FLAG_AUTOREGISTER) {
					continue observer;
				}
				if observer.world_types & BUILD_WORLD_TYPE_SIMULATION {
					print_to_builder(*builder, "\t\tregister_%(world);\n", observer.type_data.name);
				}
			}
		print_to_builder(*builder, "\t}\n");
	print_to_builder(*builder, "}\n");
    return builder_to_string(*builder);
}

