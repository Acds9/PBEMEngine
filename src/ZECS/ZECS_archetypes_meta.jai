#import "Basic";
#import "Compiler";
#import "Sort";

generate_file_loads :: () -> string {
	builder: String_Builder;
   	
	files := string.[
		"H:/PBEMJai/src/zmath.jai",
		"bit_field.jai",
		"ZECS/generated/ZECS_constants_gen.jai",
	];
   
   	for files {
		print_to_builder(*builder, "#load \"%\"\n", it);
	}
 
    
    return builder_to_string(*builder);
}

get_archetype_names :: (metadata: []Archetype_Build_Metadata) -> [..]string {
    names : [..]string;
    for metadata {
        array_add(*names, it.name);
    }
    return names;
}

generate_archetype_database :: (metadata: []Archetype_Build_Metadata) -> string {
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

		print_to_builder(*builder, "\tarchetype_components: []Type;\n");

		print_to_builder(*builder, "\ttags: ZTags;\n");
		print_to_builder(*builder, "\tchunk_size: u32;\n");
		print_to_builder(*builder, "\tinitializer: u32;\n");

	print_to_builder(*builder, "}\n");


    // DATABASE
    print_to_builder(*builder, "\n// Database of all archetype data\n");
    print_to_builder(*builder, "ARCHETYPE_DATABASE :: Archetype_Data.[\n");
    
    for arch: metadata {
		print_to_builder(*builder, "\tArchetype_Data.{\n");
        print_to_builder(*builder, "\t\tname = \"%\",\n", arch.name);
		print_to_builder(*builder, "\t\tindex = %,\n", it_index);
		print_to_builder(*builder, "\t\ttype = %,\n", arch.name);
		print_to_builder(*builder, "\n");
		e_c_array: [..]Type;
		e_c_size_array: [..]u32;
		e_c_stride_array: [..]u32;
		e_c_mask: Bit_Field(MAX_ENTITY_COMPONENTS);
		for comp: arch.entity_components {
			comp_type := get_entity_component_type(comp);
			comp_idx := get_entity_component_bit_index(comp_type);

			array_add(*e_c_array, comp_type);
			array_add(*e_c_size_array, get_entity_component_size(comp_type));
			array_add(*e_c_stride_array, get_entity_component_size(comp_type)); // For now it's identical we can adjust for alignement later if needed
			bit_set(*e_c_mask, comp_idx);
		}

		entity_data_array := bit_field_as_u64_array(e_c_mask);

		print_to_builder(*builder, "\t\tentity_component_mask		= .{.%},\n", entity_data_array);

		a_c_array: [..]Type;
		a_c_mask: Bit_Field(MAX_ENTITY_COMPONENTS);
		for comp: arch.arch_components {
			comp_type := get_archetype_component_type(comp);
			comp_idx := get_archetype_component_bit_index(comp_type);

			array_add(*a_c_array, comp_type);
			bit_set(*a_c_mask, comp_idx);
		}

		arch_data_array := bit_field_as_u64_array(a_c_mask);

		print_to_builder(*builder, "\t\tarchetype_component_mask	= .{.%},\n", arch_data_array);
		print_to_builder(*builder, "\n");
		
		print_to_builder(*builder, "\t\tentity_components			= .%,\n", e_c_array);
		print_to_builder(*builder, "\t\tentity_components_sizes		= .%,\n", e_c_size_array);
		print_to_builder(*builder, "\t\tentity_components_strides	= .%,\n", e_c_stride_array);
		print_to_builder(*builder, "\n");

		print_to_builder(*builder, "\t\tarchetype_components		= .%,\n", a_c_array);
		print_to_builder(*builder, "\n");
		
		print_to_builder(*builder, "\t\ttags						= cast,no_check(ZTags)%,\n", arch.tags); // TODO: change to actual names to see what it is?
		
		print_to_builder(*builder, "\t\tchunk_size					= %,\n", arch.chunk_size); 

		print_to_builder(*builder, "\t\tinitializer					= %,\n", arch.chunk_size); 

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
    
    return builder_to_string(*builder);
}



//
// Code Generation - Lookup Functions
//

// Generates: get_archetype_storage_index(Type) -> u16
// Maps archetype types to their storage indices
generate_archetype_index_lookup :: (metadata: []Archetype_Build_Metadata) -> string {
    builder: String_Builder;
    names := get_archetype_names(metadata);
    quick_sort(names, compare_strings);
    
    print_to_builder(*builder, "\n// Get storage index for archetype type\n");
    print_to_builder(*builder, "get_archetype_storage_index :: (t: Type) -> u16 {\n");
    print_to_builder(*builder, "\tif t == {\n");
    
    for names {
        print_to_builder(*builder, "\t\tcase %; return %;\n", it, it_index);
    }
    
    print_to_builder(*builder, "\t\tcase; return 0;\n");
    print_to_builder(*builder, "\t}\n");
    print_to_builder(*builder, "}\n");
    
    return builder_to_string(*builder);
}

// Generates: get_archetype(idx) -> Type
// Maps indices to the archetype Type
generate_index_archetype_lookup :: (metadata: []Archetype_Build_Metadata) -> string{
	builder: String_Builder;
    names := get_archetype_names(metadata);
    quick_sort(names, compare_strings);
    
    print_to_builder(*builder, "\n// Get archetype Type for storage index\n");
    print_to_builder(*builder, "get_archetype :: (idx: u16) -> Type {\n");
    print_to_builder(*builder, "\tif idx == {\n");
    
    for names {
        print_to_builder(*builder, "\t\tcase %; return %;\n", it_index, it);
    }
    
    print_to_builder(*builder, "\t\tcase; return void;\n");
    print_to_builder(*builder, "\t}\n");
    print_to_builder(*builder, "}\n");
    
    return builder_to_string(*builder);
}

generate_string_to_arch_type :: (arch_names: []string) -> string {
	builder: String_Builder;

	quick_sort(arch_names, compare_strings);

	print_to_builder(*builder, "\n");
	print_to_builder(*builder, "get_archetype :: (name: string) -> Type {\n");
	print_to_builder(*builder, "\tif name == {\n");

	for arch_names {
		print_to_builder(*builder, "\t\tcase \"%\"; return %;\n", it, it);
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
generate_component_storage_getter :: (metadata: []Archetype_Build_Metadata) -> string {
    builder: String_Builder;
    
    print_to_builder(*builder, "\n// Get component storage for archetype/component pair\n");
    print_to_builder(*builder, "get_EC_storage_ptr :: (world: *ZWorld, arch: Type, $T: Type) -> *Entity_Component_Storage {\n");
    print_to_builder(*builder, "\tif arch == {\n");
    
    for arch: metadata {
        print_to_builder(*builder, "\t\tcase %;\n", arch.name);
        print_to_builder(*builder, "\t\t\ta_s := *world.world_archetypes[get_archetype_storage_index(%)];\n", arch.name);
        print_to_builder(*builder, "\t\t\tif T == {\n");
        
        for comp: arch.entity_components {
            print_to_builder(*builder, "\t\t\t\tcase %; return *a_s.entity_components[%];\n", comp, it_index);
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
generate_entity_component_initializers :: (metadata: []Archetype_Build_Metadata) -> string { // TODO: need to sort these metadatas
    builder: String_Builder;
    
    for arch: metadata {
        print_to_builder(*builder, "\n// Initialize entity components for %\n", arch.name);
        print_to_builder(*builder, "init_entity_components_% :: (storage: *Archetype_Storage, entity_index: u32) {\n", arch.name);
        
        for comp: arch.entity_components {
            //comp_type := get_entity_component_type(comp);
			//comp_idx := get_entity_component_index(comp_type);
            print_to_builder(*builder, "\t%_ptr := cast(*%) (storage.entity_components[%].data.data + entity_index * storage.entity_components[%].stride);\n", comp, comp, it_index, it_index);
            print_to_builder(*builder, "\t<<%_ptr = %.{};\n", comp, comp);
        }
        
        print_to_builder(*builder, "}\n");
    }
    
    return builder_to_string(*builder);
}

// Generates: get_entity_initializer(Type) -> (storage: *Archetype_Storage, index: u32) -> void
// Maps archetype type to its initializer function
generate_entity_initializer_dispatch :: (metadata: []Archetype_Build_Metadata) -> string {
    builder: String_Builder;
    
    print_to_builder(*builder, "\n// Initialize entity components for archetype\n");
    print_to_builder(*builder, "init_entity_components :: (t: Type, storage: *Archetype_Storage, entity_index: u32) {\n");
    print_to_builder(*builder, "\tif t == {\n");
    
    for arch: metadata {
        print_to_builder(*builder, "\t\tcase %; init_entity_components_%(storage, entity_index);\n", 
                        arch.name, arch.name);
    }
    
    print_to_builder(*builder, "\t\tcase; // Unknown archetype\n");
    print_to_builder(*builder, "\t}\n");
    print_to_builder(*builder, "}\n");
    
    return builder_to_string(*builder);
}

generate_archetype_component_index_getters :: (metadata: []Archetype_Build_Metadata) -> string {
	builder: String_Builder;

	print_to_builder(*builder, "\n// Archetype component getters\n");
	for archetype: metadata {
		print_to_builder(*builder, "get_%_entity_component_index :: (t: Type) -> u16  {\n", archetype.name);
			print_to_builder(*builder, "\tif t==  {\n");
			for e_c: archetype.entity_components {
				print_to_builder(*builder, "\t\tcase %; return %;\n", e_c, it_index);
			}
			print_to_builder(*builder, "\t\tcase; return 0;\n");
			print_to_builder(*builder, "\t}\n");

		print_to_builder(*builder, "}\n");

		print_to_builder(*builder, "get_%_arch_component_index :: (t: Type) -> u16  {\n", archetype.name);
			print_to_builder(*builder, "\tif t==  {\n");
			for a_c: archetype.arch_components {
				print_to_builder(*builder, "\t\tcase %; return %;\n", a_c, it_index);
			}
			print_to_builder(*builder, "\t\tcase; return 0;\n");
			print_to_builder(*builder, "\t}\n");

		print_to_builder(*builder, "}\n");

		print_to_builder(*builder, "get_%_entity_component_type :: (idx: u16) -> Type  {\n", archetype.name);
			print_to_builder(*builder, "\tif idx==  {\n");
			for e_c: archetype.entity_components {
				print_to_builder(*builder, "\t\tcase %; return %;\n", it_index, e_c);
			}
			print_to_builder(*builder, "\t\tcase; return void;\n");
			print_to_builder(*builder, "\t}\n");

		print_to_builder(*builder, "}\n");

		print_to_builder(*builder, "get_%_arch_component_type :: (idx: u16) -> Type  {\n", archetype.name);
			print_to_builder(*builder, "\tif idx==  {\n");
			for a_c: archetype.arch_components {
				print_to_builder(*builder, "\t\tcase %; return %;\n", it_index, a_c);
			}
			print_to_builder(*builder, "\t\tcase; return void;\n");
			print_to_builder(*builder, "\t}\n");


		print_to_builder(*builder, "}\n");
	}

	print_to_builder(*builder, "get_entity_component_index :: (archetype: Type, entity_component: Type) -> u16 {\n");
		print_to_builder(*builder, "\tif archetype == {\n");
		for archetype: metadata {
			print_to_builder(*builder, "\t\tcase %; if entity_component == {\n", archetype.name);
			for e_c: archetype.entity_components {
				print_to_builder(*builder, "\t\t\tcase %; return %;\n", e_c, it_index);
			}
			print_to_builder(*builder, "\t\t}\n");
		}
		print_to_builder(*builder, "\t}\n");
		print_to_builder(*builder, "\t\treturn 0;\n");
	print_to_builder(*builder, "}\n");

	print_to_builder(*builder, "get_archetype_component_index :: (archetype: Type, archetype_component: Type) -> u16 {\n");
		print_to_builder(*builder, "\tif archetype == {\n");
		for archetype: metadata {
			print_to_builder(*builder, "\t\tcase %; if archetype_component == {\n", archetype.name);
			for a_c: archetype.arch_components {
				print_to_builder(*builder, "\t\t\tcase %; return %;\n", a_c, it_index);
			}
			print_to_builder(*builder, "\t\t}\n");
		}
		print_to_builder(*builder, "\t}\n");
		print_to_builder(*builder, "\treturn 0;\n");
	print_to_builder(*builder, "}\n");

	print_to_builder(*builder, "get_entity_component_type :: (archetype: Type, index: u16) -> Type {\n");
		print_to_builder(*builder, "\tif archetype == {\n");
		for archetype: metadata {
			print_to_builder(*builder, "\t\tcase %; if index == {\n", archetype.name);
			for e_c: archetype.entity_components {
				print_to_builder(*builder, "\t\t\tcase %; return %;\n", it_index, e_c);
			}
			print_to_builder(*builder, "\t\t\tcase; return Position;\n");
			print_to_builder(*builder, "\t\t}\n");
		}
		print_to_builder(*builder, "\t}\n");
		print_to_builder(*builder, "\treturn void;\n");
	print_to_builder(*builder, "}\n");

	print_to_builder(*builder, "get_archetype_component_type :: (archetype: Type, index: u16) -> Type {\n");
		print_to_builder(*builder, "\tif archetype == {\n");
		for archetype: metadata {
			print_to_builder(*builder, "\t\tcase %; if index == {\n", archetype.name);
			for a_c: archetype.arch_components {
				print_to_builder(*builder, "\t\t\tcase %; return %;\n", it_index, a_c);
			}
			print_to_builder(*builder, "\t\t}\n");
			
		}
		print_to_builder(*builder, "\t}\n");
		print_to_builder(*builder, "\treturn void;\n");
	print_to_builder(*builder, "}\n");

	print_to_builder(*builder, "get_archetype_component_storage :: (world: *ZWorld, archetype: Type) -> *[..]u8 {\n");
	print_to_builder(*builder, "\tif archetype == {\n");
	for archetype: metadata {
		print_to_builder(*builder, "\t\tcase %; return *world.world_archetypes[get_archetype_storage_index(%)].archetype_components;\n", archetype.name, archetype.name);
	}
		print_to_builder(*builder, "\t\tcase; return null;\n");
		print_to_builder(*builder, "\t}\n");
	print_to_builder(*builder, "}\n");

	print_to_builder(*builder, "get_archetype_component :: (world: *ZWorld, archetype: Type, $T: Type) -> *T {\n");
	print_to_builder(*builder, "\tif archetype == {\n");
	for archetype: metadata {
		print_to_builder(*builder, "\t\tcase %; if T == {\n", archetype.name);
		offset : u32;
		for a_c: archetype.arch_components {
			print_to_builder(*builder, "\t\t\tcase %; {\n", a_c);
			print_to_builder(*builder, "\t\t\t\tdata := get_archetype_component_storage(world, archetype);\n");
			print_to_builder(*builder, "\t\t\t\treturn cast,no_check(*%)(data.data + %);\n", a_c, offset);
			print_to_builder(*builder, "\t\t\t}\n");
			offset += get_archetype_component_size(get_archetype_component_type(a_c));
		}
		print_to_builder(*builder, "\t\t}\n");
	}
	print_to_builder(*builder, "\t}\n");
	print_to_builder(*builder, "\treturn null;\n");
	print_to_builder(*builder, "}\n");
	
	
	return builder_to_string(*builder);
}

generate_archetype_initialization :: (metadata: []Archetype_Build_Metadata) -> string {
	builder: String_Builder;
	
	print_to_builder(*builder, "\n// Archetype Master Initialization Function\n");
	print_to_builder(*builder, "initialize_archetypes :: (world: *ZWorld) {\n");
	for archetype: metadata {
		print_to_builder(*builder, "\tinit_archetype_%(world);\n", archetype.name);
	}
	print_to_builder(*builder, "}\n");

	return builder_to_string(*builder);
}

#load "H:/PBEMJai/src/bit_field.jai";
#load "H:/PBEMJai/src/zmath.jai";
#load "generated/ZECS_constants_gen.jai";
#load "ZECS_components.jai";
#load "generated/ZECS_components_gen.jai";