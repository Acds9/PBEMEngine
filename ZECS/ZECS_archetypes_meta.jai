#import "Basic";
#import "Compiler";
#import "Sort";
#load "ZECS_archetypes.jai";
#load "generated/ZECS_components_gen.jai";

//
// Helper Functions
//

get_archetype_names :: (metadata: []Archetype_Build_Metadata) -> [..]string {
    names : [..]string;
    for metadata {
        array_add(*names, it.name);
    }
    return names;
}

//
// Code Generation - Lookup Functions
//

// Generates: get_arch_index(Type) -> u16
// Maps archetype types to their storage indices
generate_archetype_index_lookup :: (metadata: []Archetype_Build_Metadata) -> string {
    builder: String_Builder;
    names := get_archetype_names(metadata);
    quick_sort(names, compare_strings);
    
    print_to_builder(*builder, "\n// Get storage index for archetype type\n");
    print_to_builder(*builder, "get_arch_index :: (t: Type) -> u16 {\n");
    print_to_builder(*builder, "\tif t == {\n");
    
    for names {
        print_to_builder(*builder, "\t\tcase %; return %;\n", it, it_index);
    }
    
    print_to_builder(*builder, "\t\tcase; return 0;\n");
    print_to_builder(*builder, "\t}\n");
    print_to_builder(*builder, "}\n");
    
    return builder_to_string(*builder);
}

// Generates: get_index_arch(idx) -> Type
// Maps indices to the archetype Type
generate_index_archetype_lookup :: (metadata: []Archetype_Build_Metadata) -> string{
	builder: String_Builder;
    names := get_archetype_names(metadata);
    quick_sort(names, compare_strings);
    
    print_to_builder(*builder, "\n// Get archetype Type for storage index\n");
    print_to_builder(*builder, "get_index_arch :: (idx: u16) -> Type {\n");
    print_to_builder(*builder, "\tif idx == {\n");
    
    for names {
        print_to_builder(*builder, "\t\tcase %; return %;\n", it_index, it);
    }
    
    print_to_builder(*builder, "\t\tcase; return Archetype;\n");
    print_to_builder(*builder, "\t}\n");
    print_to_builder(*builder, "}\n");
    
    return builder_to_string(*builder);
}

//
// Code Generation - Component Access
//

// Generates: get_e_c_storage_ptr(world, archetype_type, component_type) -> *Entity_Component_Storage
// Returns pointer to component storage for a specific archetype/component pair
generate_component_storage_getter :: (metadata: []Archetype_Build_Metadata) -> string {
    builder: String_Builder;
    
    print_to_builder(*builder, "\n// Get component storage for archetype/component pair\n");
    print_to_builder(*builder, "get_e_c_storage_ptr :: (world: *ZWorld, arch: Type, $T: Type) -> *Entity_Component_Storage {\n");
    print_to_builder(*builder, "\tif arch == {\n");
    
    for arch: metadata {
        print_to_builder(*builder, "\t\tcase %;\n", arch.name);
        print_to_builder(*builder, "\t\t\ta_s := *world.world_archetypes[get_arch_index(%)];\n", arch.name);
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
generate_entity_component_initializers :: (metadata: []Archetype_Build_Metadata) -> string {
    builder: String_Builder;
    
    for arch: metadata {
        print_to_builder(*builder, "\n// Initialize entity components for %\n", arch.name);
        print_to_builder(*builder, "init_entity_components_% :: (storage: *Archetype_Storage, entity_index: u32) {\n", arch.name);
        
        for comp: arch.entity_components {
            comp_type := get_entity_component_type(comp);
			comp_idx := get_entity_component_index(comp_type);
            print_to_builder(*builder, "\t%_ptr := cast(*%) (storage.entity_components[%].data.data + entity_index * storage.entity_components[%].stride);\n", comp, comp, comp_idx, comp_idx);
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

generate_archetype_database :: (metadata: []Archetype_Build_Metadata) -> string {
	builder: String_Builder;
    
    print_to_builder(*builder, "\n// Database of all archetype data\n");
    print_to_builder(*builder, "ARCHETYPE_DATABASE :: struct {\n");
    
    for arch: metadata {
        print_to_builder(*builder, "\t%_Data :: struct {\n", arch.name);

		e_c_array: [..]Type;
		e_c_size_array: [..]u32;
		e_c_stride_array: [..]u32;
		e_c_mask: Bit_Field(MAX_ENTITY_COMPONENTS);
		for comp: arch.entity_components {
			comp_type := get_entity_component_type(comp);
			comp_idx := get_entity_component_index(comp_type);

			array_add(*e_c_array, comp_type);
			array_add(*e_c_size_array, get_entity_component_size(comp_type));
			array_add(*e_c_stride_array, get_entity_component_size(comp_type)); // For now it's identical we can adjust for alignement later if needed
			bit_set(*e_c_mask, comp_idx);
		}

		entity_data_array := bit_field_as_u64_array(e_c_mask);

		print_to_builder(*builder, "\t\tEntity_Component_Mask		: Bit_Field(MAX_ENTITY_COMPONENTS) : .{.%};\n", entity_data_array);

		a_c_array: [..]Type;
		a_c_mask: Bit_Field(MAX_ENTITY_COMPONENTS);
		for comp: arch.arch_components {
			comp_type := get_arch_component_type(comp);
			comp_idx := get_archetype_component_index(comp_type);

			array_add(*a_c_array, comp_type);
			bit_set(*a_c_mask, comp_idx);
		}

		arch_data_array := bit_field_as_u64_array(a_c_mask);

		print_to_builder(*builder, "\t\tArchetype_Component_Mask	: Bit_Field(MAX_ARCH_COMPONENTS) : .{.%};\n", arch_data_array);
		print_to_builder(*builder, "\n");
		
		print_to_builder(*builder, "\t\tEntity_Components			: [%]Type : .%;\n", e_c_array.count, e_c_array);
		print_to_builder(*builder, "\t\tEntity_Components_sizes		: [%]u32 : .%;\n", e_c_array.count, e_c_size_array);
		print_to_builder(*builder, "\t\tEntity_Components_strides	: [%]u32 : .%;\n", e_c_array.count, e_c_stride_array);
		print_to_builder(*builder, "\n");

		print_to_builder(*builder, "\t\tArchetype_Components		: [%]Type : .%;\n", a_c_array.count, a_c_array);
		print_to_builder(*builder, "\n");

		print_to_builder(*builder, "\t\tTags						: ZTags : cast,no_check(ZTags)%;\n", arch.tags); // TODO: change to actual names to see what it is?
		
		print_to_builder(*builder, "\t\tchunk_size					: u32 : %;\n", arch.chunk_size); 

		print_to_builder(*builder, "\t\tinitializer					: u32 : %;\n", arch.chunk_size); 

		// We do not need to add defaults, they are already initialized constants in the component definition, just refer to them directly

		print_to_builder(*builder, "\t}\n");
    }
    print_to_builder(*builder, "}\n");
    
    return builder_to_string(*builder);
}

generate_archetype_initializers :: (metadata: []Archetype_Build_Metadata) -> string {
	builder: String_Builder;

	for arch: metadata {
		print_to_builder(*builder, "\n// Archetype Storage initializer for %\n", arch.name);
		print_to_builder(*builder, "initialize_storage_% :: (alloc: Allocator) -> Archetype_Storage {\n", arch.name);

			print_to_builder(*builder, "\tstorage: Archetype_Storage;\n");
			print_to_builder(*builder, "\n");

			print_to_builder(*builder, "\tstorage.entity_components.allocator = alloc;\n");
			print_to_builder(*builder, "\tstorage.archetype_components.allocator = alloc;\n");
			print_to_builder(*builder, "\tstorage.free_indices.allocator = alloc;\n");
			print_to_builder(*builder, "\tstorage.generations.allocator = alloc;\n");
			print_to_builder(*builder, "\n");

			print_to_builder(*builder, "\tstorage.entity_component_mask = ARCHETYPE_DATABASE.%_Data.Entity_Component_Mask;\n", arch.name);
			print_to_builder(*builder, "\tstorage.archetype_component_mask = ARCHETYPE_DATABASE.%_Data.Archetype_Component_Mask;\n", arch.name);
			print_to_builder(*builder, "\n");

			print_to_builder(*builder, "\tarray_resize(*storage.entity_components, ARCHETYPE_DATABASE.%_Data.Entity_Components.count);\n", arch.name);
			print_to_builder(*builder, "\tarray_resize(*storage.archetype_components, ARCHETYPE_DATABASE.%_Data.Entity_Components.count);\n", arch.name);
			print_to_builder(*builder, "\n");

			print_to_builder(*builder, "\tfor ARCHETYPE_DATABASE.%_Data.Entity_Components {\n", arch.name);
				print_to_builder(*builder, "\t\tstorage.entity_components[it_index].type = it;\n");
				print_to_builder(*builder, "\t\tstorage.entity_components[it_index].stride = get_entity_component_size(it);\n"); // Size, stride? 
			print_to_builder(*builder, "\t}\n");
			print_to_builder(*builder, "\n");

			for arch.a_c_defaults {
				print_to_builder(*builder, "\tstorage.archetype_components[%].type = %;\n", it_index, it.comp_type_name);
				print_to_builder(*builder, "\tstorage.archetype_components[%].data = Any.{type = type_info(%), value_pointer = cast(*void)(*%.DEFAULT_%)};\n", it_index, it.comp_type_name, arch.name, it.comp_type_name);
			}

			print_to_builder(*builder, "\tstorage.tags = ARCHETYPE_DATABASE.%_Data.Tags;\n", arch.name);
			
			print_to_builder(*builder, "\tstorage.chunk_size = ARCHETYPE_DATABASE.%_Data.chunk_size;\n", arch.name);

		print_to_builder(*builder, "\treturn storage;\n");
		print_to_builder(*builder, "}\n");
	}
    return builder_to_string(*builder);
}

generate_archetype_initializer_getter :: (metadata: []Archetype_Build_Metadata) -> string {
	builder: String_Builder;

	print_to_builder(*builder, "\n// Archetype Storage Initializer getter\n");
	print_to_builder(*builder, "get_archetype_initializer :: (t: Type) -> Arch_Storage_Initializer  {\n");
		
		print_to_builder(*builder, "\tif t == {\n");
		for arch: metadata {
			print_to_builder(*builder, "\tcase %; return initialize_storage_%;\n", arch.name, arch.name);
			print_to_builder(*builder, "\tcase; return null;\n");
		}
		print_to_builder(*builder, "\t}\n");

	print_to_builder(*builder, "}\n");
	
	return builder_to_string(*builder);
}