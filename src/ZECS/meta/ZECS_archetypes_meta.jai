#import "Basic";
#import "Compiler";
#import "Sort";


generate_file_loads :: () -> string {
	builder: String_Builder;
   	
	files := string.[
		"H:/PBEMJai/src/zmath.jai",
		"H:/PBEMJai/src/rotor.jai",
		"bit_field.jai",
		"ZECS/generated/ZECS_constants_gen.jai",
	];
   
   	for files {
		print_to_builder(*builder, "#load \"%\"\n", it);
	}
 
    
    return builder_to_string(*builder);
}

#load "../../bit_field.jai";
generate_archetype_database :: (build_context: *Build_Context) -> string {
	builder: String_Builder;


	// STRUCT
	print_to_builder(*builder, "\n// Archetype data struct\n");
    print_to_builder(*builder, "Archetype_Data :: struct {\n");

		print_to_builder(*builder, "\tname: string;\n");
		print_to_builder(*builder, "\tindex: u16;\n");
		print_to_builder(*builder, "\ttype: Type;\n");

		print_to_builder(*builder, "\tentity_component_mask: Bit_Field(MAX_ENTITY_COMPONENTS);\n");
		print_to_builder(*builder, "\tarchetype_component_mask: Bit_Field(MAX_ARCH_COMPONENTS);\n");

		print_to_builder(*builder, "\tentity_components: []Type;\n");
		print_to_builder(*builder, "\tentity_components_sizes: []u32;\n");
		print_to_builder(*builder, "\tentity_components_strides: []u32;\n");
		print_to_builder(*builder, "\tcomponent_data_size_intel: []u32;\n");
		print_to_builder(*builder, "\tcomponent_intel_bitfield: []Bit_Field(64, u8);\n");
		
		print_to_builder(*builder, "\tarchetype_components: []Type;\n");

		print_to_builder(*builder, "\ttags: ZTags;\n");
		print_to_builder(*builder, "\tchunk_size: u32;\n");
		print_to_builder(*builder, "\tinitializer: u32;\n");

	print_to_builder(*builder, "}\n");


    // DATABASE
    print_to_builder(*builder, "\n// Database of all archetype data\n");
    print_to_builder(*builder, "ARCHETYPE_DATABASE :: Archetype_Data.[\n");
    
    for archetype: build_context.archetypes {
		print_to_builder(*builder, "\tArchetype_Data.{\n");
        print_to_builder(*builder, "\t\tname = \"%\",\n", archetype.type_data.name);
		print_to_builder(*builder, "\t\tindex = %,\n", it_index);
		print_to_builder(*builder, "\t\ttype = %,\n", get_type(archetype.type_data));
		print_to_builder(*builder, "\n");
		e_c_array: [..]Type;
		e_c_size_array: [..]u32;
		e_c_stride_array: [..]u32;
		e_c_bits: [..]u32;
		for comp: archetype.entity_components {
			comp_type := get_type(comp);
			comp_idx := lookup_ec_bit_index(build_context, comp);

			array_add(*e_c_array, comp_type);
			array_add(*e_c_size_array, cast(u32) comp.runtime_size);
			array_add(*e_c_stride_array, cast(u32) comp.runtime_size); // For now it's identical we can adjust for alignement later if needed
			array_add(*e_c_bits, comp_idx);
		}

		e_c_mask := compute_bitmask(build_context.entity_components.count, e_c_bits);

		print_to_builder(*builder, "\t\tentity_component_mask		= .{.%},\n", e_c_mask);

		a_c_array: [..]Type;
		a_c_bits: [..]u32;
		for comp: archetype.archetype_components {
			comp_type := get_type(comp);
			comp_idx := lookup_ac_bit_index(build_context, comp);

			array_add(*a_c_array, comp_type);
			array_add(*a_c_bits, comp_idx);
		}

		a_c_mask := compute_bitmask(build_context.archetype_components.count, a_c_bits);

		print_to_builder(*builder, "\t\tarchetype_component_mask	= .{.%},\n", a_c_mask);
		print_to_builder(*builder, "\n");
		
		print_to_builder(*builder, "\t\tentity_components			= .%,\n", e_c_array);
		print_to_builder(*builder, "\t\tentity_components_sizes		= .%,\n", e_c_size_array);
		print_to_builder(*builder, "\t\tentity_components_strides	= .%,\n", e_c_stride_array);

		intel_sizes : [INTEL_LEVEL_COUNT]u32;
		intel_bit_fields : [INTEL_LEVEL_COUNT]Bit_Field(64, u8);
		for 0..INTEL_LEVEL_COUNT-1 {
			size : u32;
			for comp: archetype.entity_components {
				size += cast(u32) comp.runtime_size;
			}
			intel_sizes[it] = size;
		}
		print_to_builder(*builder, "\t\tcomponent_data_size_intel	= .%, // What size the entity component data blob will be at the given intel level\n", intel_sizes);

		print_to_builder(*builder, "\t\tcomponent_data_size_intel	= .%, // What size the entity component data blob will be at the given intel level\n", intel_sizes);

		print_to_builder(*builder, "\n");

		print_to_builder(*builder, "\t\tarchetype_components		= .%,\n", a_c_array);
		print_to_builder(*builder, "\n");
		
		print_to_builder(*builder, "\t\ttags						= cast,no_check(ZTags)%,\n", archetype.tags); // TODO: change to actual names to see what it is?
		
		print_to_builder(*builder, "\t\tchunk_size					= %,\n", archetype.chunk_size); 

		print_to_builder(*builder, "\t\tinitializer					= %,\n", archetype.chunk_size); 

		// We do not need to add defaults, they are already initialized constants in the component definition, just refer to them directly

		print_to_builder(*builder, "\t},\n");
    }
    print_to_builder(*builder, "];\n");

	// GETTERS
	print_to_builder(*builder, "\n// Archetype Data Getters\n");
    print_to_builder(*builder, "get_archetype_data :: (idx: u16) -> *Archetype_Data{\n");
	print_to_builder(*builder, "\treturn *ARCHETYPE_DATABASE[idx];\n");
	print_to_builder(*builder, "};\n");

    print_to_builder(*builder, "get_archetype_data :: (t: Type) -> *Archetype_Data{\n");
	print_to_builder(*builder, "\treturn *ARCHETYPE_DATABASE[get_archetype_storage_index(t)];\n");
	print_to_builder(*builder, "};\n");

	print_to_builder(*builder, "get_archetype_data_size_intel :: (t: Type, intel_level: u8) -> u32{\n");
	print_to_builder(*builder, "\tdata := *ARCHETYPE_DATABASE[get_archetype_storage_index(t)];\n");
	print_to_builder(*builder, "\tif intel_level >= data.component_data_size_intel.count {\n");
	print_to_builder(*builder, "\t\t return data.component_data_size_intel[data.component_data_size_intel.count-1];\n");
	print_to_builder(*builder, "\t};\n");
	print_to_builder(*builder, "\treturn ARCHETYPE_DATABASE[get_archetype_storage_index(t)].component_data_size_intel[intel_level];\n");
	print_to_builder(*builder, "};\n");
    
    return builder_to_string(*builder);
}

//
// Code Generation - Serialization Functions
//

generate_archetype_serializers :: (build_context: *Build_Context) -> string { 
	builder: String_Builder;

	print_to_builder(*builder, "\n// Serialize archetype component data given an entity\n");
    print_to_builder(*builder, "serialize_entity_component_data :: (dest: *[..]u8, entity: ZEntity, world: *ZWorld, intel_level: u8, offset: *s64) {\n");
		print_to_builder(*builder, "\tarchetype := get_archetype(entity.archetype);\n");
		print_to_builder(*builder, "\tarchetype_data := get_archetype_data(archetype);\n");
		print_to_builder(*builder, "\tarray_resize(dest, dest.count + get_archetype_data_size_intel(archetype, intel_level)); // Ensure we can fit the data\n");
		print_to_builder(*builder, "\tif archetype == {;\n");
			for archetype: build_context.archetypes {
				print_to_builder(*builder, "\t\tcase %; {\n", get_type(archetype.type_data));
					for component: archetype.entity_components {
						if !array_find(component.notes, "serialize") {
							continue;
						}
						print_to_builder(*builder, "\t\t\t%_ptr, %_found := get_entity_component(world, entity, %);\n", to_lower_copy(component.name), to_lower_copy(component.name), component.name);
						print_to_builder(*builder, "\t\t\tassert(%_found, \"Could not find component % in serialize_entity_component_data, this shouldn't happen\");\n", to_lower_copy(component.name), component.name);
						print_to_builder(*builder, "\t\t\tserialize(dest, %_ptr, offset);\n", to_lower_copy(component.name));
					}
					
				print_to_builder(*builder, "\t\t}\n");
			}
   	print_to_builder(*builder, "\t}\n");
	print_to_builder(*builder, "}\n");
	print_to_builder(*builder, "\n// Deserialize archetype component data to component storage given an archetype\n");
    print_to_builder(*builder, "deserialize_entity_component_data :: (entity: ZEntity, world: *ZWorld, src: []u8, intel_level: u8, offset: *s64) {\n");
		print_to_builder(*builder, "\tarchetype := get_archetype(entity.archetype);\n");
		print_to_builder(*builder, "\tarchetype_data := get_archetype_data(archetype);\n");
		print_to_builder(*builder, "\tif archetype == {;\n");
			for archetype: build_context.archetypes {
				print_to_builder(*builder, "\t\tcase %; {\n", get_type(archetype.type_data));
					for component: archetype.entity_components {
						if !array_find(component.notes, "serialize") {
							continue;
						}
						print_to_builder(*builder, "\t\t\t%_ptr, %_found := get_entity_component(world, entity, %);\n", to_lower_copy(component.name), to_lower_copy(component.name), component.name);
						print_to_builder(*builder, "\t\t\tassert(%_found, \"Could not find component % in deserialize_entity_component_data, this shouldn't happen\");\n", to_lower_copy(component.name), component.name);
						print_to_builder(*builder, "\t\t\tdeserialize(%_ptr, src, offset);\n", to_lower_copy(component.name));
					}
					
				print_to_builder(*builder, "\t\t}\n");
			}
   	print_to_builder(*builder, "\t}\n");
	print_to_builder(*builder, "}\n");
	print_to_builder(*builder, "\n// Deserialize archetype component data to buffer given an archetype\n");
    print_to_builder(*builder, "deserialize_entity_component_data :: (dest: *[..]u8, src: []u8, archetype_idx: u16, intel_level: u8, offset: *s64) {\n");
		print_to_builder(*builder, "\tarchetype := get_archetype(archetype_idx);\n");
		print_to_builder(*builder, "\tdata_size := get_archetype_data_size_intel(archetype, intel_level);\n");
		print_to_builder(*builder, "\tarray_resize(dest, dest.count + data_size);\n");
		print_to_builder(*builder, "\tdeserialize_from_buffer(dest.data, src, offset, data_size);\n");
	print_to_builder(*builder, "}\n");

	return builder_to_string(*builder);
}

//
// Code Generation - Lookup Functions
//

// Generates: get_archetype_storage_index(Type) -> u16
// Maps archetype types to their storage indices
generate_archetype_index_lookup :: (build_context: *Build_Context) -> string {
    builder: String_Builder;
    
    print_to_builder(*builder, "\n// Get storage index for archetype type\n");
    print_to_builder(*builder, "get_archetype_storage_index :: (t: Type) -> u16 {\n");
    print_to_builder(*builder, "\tif t == {\n");
    
    for build_context.archetypes {
        print_to_builder(*builder, "\t\tcase %; return %;\n", get_type(it.type_data), it_index);
    }
    
    print_to_builder(*builder, "\t\tcase; return 0;\n");
    print_to_builder(*builder, "\t}\n");
    print_to_builder(*builder, "}\n");
    
    return builder_to_string(*builder);
}

// Generates: get_archetype(idx) -> Type
// Maps indices to the archetype Type
generate_index_archetype_lookup :: (build_context: *Build_Context) -> string{
	builder: String_Builder;
    
    print_to_builder(*builder, "\n// Get archetype Type for storage index\n");
    print_to_builder(*builder, "get_archetype :: (idx: u16) -> Type {\n");
    print_to_builder(*builder, "\tif idx == {\n");
    
    for build_context.archetypes {
        print_to_builder(*builder, "\t\tcase %; return %;\n", it_index, get_type(it.type_data));
    }
    
    print_to_builder(*builder, "\t\tcase; return void;\n");
    print_to_builder(*builder, "\t}\n");
    print_to_builder(*builder, "}\n");
    
    return builder_to_string(*builder);
}

//
// Code Generation - Component Access
//

// Generates: get_EC_storage_ptr(world, archetype_type, component_type) -> *Entity_Component_Storage
// Returns pointer to component storage for a specific archetype/component pair
generate_component_storage_getter :: (build_context: *Build_Context) -> string {
    builder: String_Builder;

    print_to_builder(*builder, "\n// Get component storage for archetype/component pair\n");
    print_to_builder(*builder, "get_EC_storage_ptr :: (world: *ZWorld, arch: Type, T: Type) -> *Entity_Component_Storage {\n");
    print_to_builder(*builder, "\tif arch == {\n");
    
    for archetype: build_context.archetypes {
        print_to_builder(*builder, "\t\tcase %;\n", get_type(archetype.type_data));
        print_to_builder(*builder, "\t\t\ta_s := *world.world_archetypes[get_archetype_storage_index(%)];\n", get_type(archetype.type_data));
        print_to_builder(*builder, "\t\t\tif T == {\n");
        
        for comp: archetype.entity_components {
            print_to_builder(*builder, "\t\t\t\tcase %; return *a_s.entity_components[%];\n", get_type(comp), it_index);
        }
        
        print_to_builder(*builder, "\t\t\t\tcase; return null;\n");
        print_to_builder(*builder, "\t\t\t}\n");
    }
    
    print_to_builder(*builder, "\t\tcase; return null;\n");
    print_to_builder(*builder, "\t}\n");
    print_to_builder(*builder, "}\n");
    
    return builder_to_string(*builder);
}

//
// Code Generation - Entity Initialization
//

// Generates: init_entity_components_[Archetype](storage, entity_index)
// Creates typed pointers to each component for initialization
generate_entity_component_initializers :: (build_context: *Build_Context) -> string { // TODO: need to sort these metadatas
    builder: String_Builder;
    
    for archetype: build_context.archetypes {
        print_to_builder(*builder, "\n// Initialize entity components for %\n", get_type(archetype.type_data));
        print_to_builder(*builder, "init_entity_components_% :: (storage: *Archetype_Storage, entity_index: u32) {\n", get_type(archetype.type_data));
        
        for comp: archetype.entity_components {
            //comp_type := get_entity_component_type(comp);
			//comp_idx := get_entity_component_index(comp_type);
            print_to_builder(*builder, "\t%_ptr := cast(*%) (storage.entity_components[%].data.data + entity_index * storage.entity_components[%].stride);\n", get_type(comp), get_type(comp), it_index, it_index);
            print_to_builder(*builder, "\t<<%_ptr = %.{};\n", get_type(comp), get_type(comp));
        }
        
        print_to_builder(*builder, "}\n");
    }
    
    return builder_to_string(*builder);
}

// Generates: get_entity_initializer(Type) -> (storage: *Archetype_Storage, index: u32) -> void
// Maps archetype type to its initializer function
generate_entity_initializer_dispatch :: (build_context: *Build_Context) -> string {
    builder: String_Builder;
    
    print_to_builder(*builder, "\n// Initialize entity components for archetype\n");
    print_to_builder(*builder, "init_entity_components :: (t: Type, storage: *Archetype_Storage, entity_index: u32) {\n");
    print_to_builder(*builder, "\tif t == {\n");
    
    for archetype: build_context.archetypes {
        print_to_builder(*builder, "\t\tcase %; init_entity_components_%(storage, entity_index);\n",
                        get_type(archetype.type_data), get_type(archetype.type_data));
    }
    
    print_to_builder(*builder, "\t\tcase; // Unknown archetype\n");
    print_to_builder(*builder, "\t}\n");
    print_to_builder(*builder, "}\n");
    
    return builder_to_string(*builder);
}

generate_archetype_component_index_getters :: (build_context: *Build_Context) -> string {
	builder: String_Builder;

	print_to_builder(*builder, "\n// Archetype component getters\n");
	for archetype: build_context.archetypes {
		print_to_builder(*builder, "get_%_entity_component_index :: (t: Type) -> u16  {\n", get_type(archetype.type_data));
			print_to_builder(*builder, "\tif t==  {\n");
			for e_c: archetype.entity_components {
				print_to_builder(*builder, "\t\tcase %; return %;\n", get_type(e_c), it_index);
			}
			print_to_builder(*builder, "\t\tcase; return 0;\n");
			print_to_builder(*builder, "\t}\n");

		print_to_builder(*builder, "}\n");

		print_to_builder(*builder, "get_%_arch_component_index :: (t: Type) -> u16  {\n", get_type(archetype.type_data));
			print_to_builder(*builder, "\tif t==  {\n");
			for a_c: archetype.archetype_components {
				print_to_builder(*builder, "\t\tcase %; return %;\n", get_type(a_c), it_index);
			}
			print_to_builder(*builder, "\t\tcase; return 0;\n");
			print_to_builder(*builder, "\t}\n");

		print_to_builder(*builder, "}\n");

		print_to_builder(*builder, "get_%_entity_component_type :: (idx: u16) -> Type  {\n", get_type(archetype.type_data));
			print_to_builder(*builder, "\tif idx==  {\n");
			for e_c: archetype.entity_components {
				print_to_builder(*builder, "\t\tcase %; return %;\n", it_index, get_type(e_c));
			}
			print_to_builder(*builder, "\t\tcase; return void;\n");
			print_to_builder(*builder, "\t}\n");

		print_to_builder(*builder, "}\n");

		print_to_builder(*builder, "get_%_arch_component_type :: (idx: u16) -> Type  {\n", get_type(archetype.type_data));
			print_to_builder(*builder, "\tif idx==  {\n");
			for a_c: archetype.archetype_components {
				print_to_builder(*builder, "\t\tcase %; return %;\n", it_index, get_type(a_c));
			}
			print_to_builder(*builder, "\t\tcase; return void;\n");
			print_to_builder(*builder, "\t}\n");


		print_to_builder(*builder, "}\n");
	}

	print_to_builder(*builder, "get_entity_component_index :: (archetype: Type, entity_component: Type) -> u16 {\n");
		print_to_builder(*builder, "\tif archetype == {\n");
		for archetype: build_context.archetypes {
			print_to_builder(*builder, "\t\tcase %; if entity_component == {\n", get_type(archetype.type_data));
			for e_c: archetype.entity_components {
				print_to_builder(*builder, "\t\t\tcase %; return %;\n", get_type(e_c), it_index);
			}
			print_to_builder(*builder, "\t\t}\n");
		}
		print_to_builder(*builder, "\t}\n");
		print_to_builder(*builder, "\t\treturn 0;\n");
	print_to_builder(*builder, "}\n");

	print_to_builder(*builder, "get_archetype_component_index :: (archetype: Type, archetype_component: Type) -> u16 {\n");
		print_to_builder(*builder, "\tif archetype == {\n");
		for archetype: build_context.archetypes {
			print_to_builder(*builder, "\t\tcase %; if archetype_component == {\n", get_type(archetype.type_data));
			for a_c: archetype.archetype_components {
				print_to_builder(*builder, "\t\t\tcase %; return %;\n", get_type(a_c), it_index);
			}
			print_to_builder(*builder, "\t\t}\n");
		}
		print_to_builder(*builder, "\t}\n");
		print_to_builder(*builder, "\treturn 0;\n");
	print_to_builder(*builder, "}\n");

	print_to_builder(*builder, "get_entity_component_type :: (archetype: Type, index: u16) -> Type {\n");
		print_to_builder(*builder, "\tif archetype == {\n");
		for archetype: build_context.archetypes {
			print_to_builder(*builder, "\t\tcase %; if index == {\n", get_type(archetype.type_data));
			for e_c: archetype.entity_components {
				print_to_builder(*builder, "\t\t\tcase %; return %;\n", it_index, get_type(e_c));
			}
			print_to_builder(*builder, "\t\t\tcase; return Position;\n");
			print_to_builder(*builder, "\t\t}\n");
		}
		print_to_builder(*builder, "\t}\n");
		print_to_builder(*builder, "\treturn void;\n");
	print_to_builder(*builder, "}\n");

	print_to_builder(*builder, "get_archetype_component_type :: (archetype: Type, index: u16) -> Type {\n");
		print_to_builder(*builder, "\tif archetype == {\n");
		for archetype: build_context.archetypes {
			print_to_builder(*builder, "\t\tcase %; if index == {\n", get_type(archetype.type_data));
			for a_c: archetype.archetype_components {
				print_to_builder(*builder, "\t\t\tcase %; return %;\n", it_index, get_type(a_c));
			}
			print_to_builder(*builder, "\t\t}\n");
			
		}
		print_to_builder(*builder, "\t}\n");
		print_to_builder(*builder, "\treturn void;\n");
	print_to_builder(*builder, "}\n");

	print_to_builder(*builder, "get_archetype_component_storage :: (world: *ZWorld, archetype: Type) -> *[..]u8 {\n");
	print_to_builder(*builder, "\tif archetype == {\n");
	for archetype: build_context.archetypes {
		print_to_builder(*builder, "\t\tcase %; return *world.world_archetypes[get_archetype_storage_index(%)].archetype_components;\n", get_type(archetype.type_data), get_type(archetype.type_data));
	}
		print_to_builder(*builder, "\t\tcase; return null;\n");
		print_to_builder(*builder, "\t}\n");
	print_to_builder(*builder, "}\n");

	print_to_builder(*builder, "get_archetype_component :: (world: *ZWorld, archetype: Type, $T: Type) -> *T {\n");
	print_to_builder(*builder, "\tif archetype == {\n");
	for archetype: build_context.archetypes {
		print_to_builder(*builder, "\t\tcase %; if T == {\n", get_type(archetype.type_data));
		offset : u32;
		for a_c: archetype.archetype_components {
			print_to_builder(*builder, "\t\t\tcase %; {\n", get_type(a_c));
			print_to_builder(*builder, "\t\t\t\tdata := get_archetype_component_storage(world, archetype);\n");
			print_to_builder(*builder, "\t\t\t\treturn cast,no_check(*%)(data.data + %);\n", get_type(a_c), offset);
			print_to_builder(*builder, "\t\t\t}\n");
			offset += xx a_c.runtime_size;
		}
		print_to_builder(*builder, "\t\t}\n");
	}
	print_to_builder(*builder, "\t}\n");
	print_to_builder(*builder, "\treturn null;\n");
	print_to_builder(*builder, "}\n");
	
	
	return builder_to_string(*builder);
}

generate_archetype_initialization :: (build_context: *Build_Context) -> string {
	builder: String_Builder;
	
	print_to_builder(*builder, "\n// Archetype Master Initialization Function\n");
	print_to_builder(*builder, "initialize_archetypes :: (world: *ZWorld) {\n");
	for archetype: build_context.archetypes {
		print_to_builder(*builder, "\tinit_archetype_%(world);\n", get_type(archetype.type_data));
	}
	print_to_builder(*builder, "}\n");

	return builder_to_string(*builder);
}