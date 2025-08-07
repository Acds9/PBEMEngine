#import "Basic";
#import "Compiler";
#import "Sort";

Archetype_Build_Metadata :: struct {
    name                : string;
    entity_components   : [..]string;
    arch_components     : [..]string;
	a_c_defaults		: [..]Archetype_Component_Default;
    tags                : string;  
    chunk_size          : u32 = 32;
}

Archetype_Component_Default :: struct {
	comp_type_name		: string;
	data_type			: *Type_Info;
	data_ptr			: *u8;
	data_size			: u32;
}

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
            comp_idx := sprint("get_entity_component_index(%)", comp);
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

//
// Main Generation Entry Point
//

generate_archetype_code :: (metadata: []Archetype_Build_Metadata) -> string {
    builder: String_Builder;
    
	// Database
	append(*builder, generate_archetype_database(metadata));

    // Core lookup functions
    append(*builder, generate_archetype_index_lookup(metadata));
	append(*builder, generate_index_archetype_lookup(metadata));
    append(*builder, generate_component_storage_getter(metadata));
    
    // Entity initialization
    append(*builder, generate_entity_component_initializers(metadata));
    append(*builder, generate_entity_initializer_dispatch(metadata));
    
    return builder_to_string(*builder);
}


gather_archetypes :: (typechecked: *Message_Typechecked) -> [..]Archetype_Build_Metadata {
	archetypes : [..]Archetype_Build_Metadata;
	
	for typechecked.structs {
        info := it.expression.defined_type;
        
        if is_subclass_of(info, "Archetype") && info.name != "Archetype" {
			archetype : Archetype_Build_Metadata;
			archetype.name = info.name;

			for member: info.members {
				if(member.flags & .CONSTANT) {
					if(member.name == "ENTITY_COMPONENTS") {
						// We know it's an array
						array_type := cast(*Type_Info_Array)member.type;
						count := array_type.array_count;
						
						any: Any;
						any.type = member.type;

						if(member.offset_into_constant_storage >= 0) {
							any.value_pointer = info.constant_storage.data + member.offset_into_constant_storage;
						}
						else {
							any.value_pointer = info.constant_storage.data + member.offset_in_bytes;
						}

						// we know array type is fixed
						data := any.value_pointer; // So the data is right here
						for i: 0..count-1 {
							pointer := data + array_type.element_type.runtime_size * i;

							item: Any;
							item_type:= array_type.element_type;
							item.value_pointer = pointer;

							// Extract
							type_ptr := (.*) cast(**Type_Info_Struct) item.value_pointer;
							if type_ptr {
								type := <<type_ptr;
								array_add(*archetype.entity_components, type.name);
							}
						}
					}
					else if (member.name == "ARCHETYPE_COMPONENTS") {
						array_type := cast(*Type_Info_Array)member.type;
						count := array_type.array_count;
						
						any: Any;
						any.type = member.type;

						if(member.offset_into_constant_storage >= 0) {
							any.value_pointer = info.constant_storage.data + member.offset_into_constant_storage;
						}
						else {
							any.value_pointer = info.constant_storage.data + member.offset_in_bytes;
						}

						// we know array type is fixed
						data := any.value_pointer; // So the data is right here
						for i: 0..count-1 {
							pointer := data + array_type.element_type.runtime_size * i;

							item: Any;
							item_type:= array_type.element_type;
							item.value_pointer = pointer;

							// Extract
							type_ptr := (.*) cast(**Type_Info_Struct) item.value_pointer;
							if type_ptr {
								type := <<type_ptr;
								array_add(*archetype.arch_components, type.name);
							}
						}
					}
					else if (member.name == "TAGS") {
						// Just extract the u64 value directly
						tags_value := <<cast(*u64)(info.constant_storage.data + member.offset_into_constant_storage);
						
						builder: String_Builder;
						print_to_builder(*builder, "%", tags_value);

						archetype.tags = builder_to_string(*builder);  // Store as u64 in metadata
						
					}
					else if (starts_with(member.name, "DEFAULT_"))
					{
						_,_,comp_name := split_from_left(member.name, "_");  // Skip "DEFAULT_"

						print("%\n", comp_name);

						default_value: Archetype_Component_Default;
						default_value.comp_type_name = comp_name;
						default_value.data_type = member.type;
						default_value.data_ptr = info.constant_storage.data + member.offset_into_constant_storage;
						default_value.data_size = cast(u32)member.type.runtime_size;

						array_add(*archetype.a_c_defaults, default_value);
					}
				}
			}
			array_add(*archetypes, archetype);
        }
    }
	return archetypes;
}

generate_archetype_database :: (metadata: []Archetype_Build_Metadata) -> string {
	builder: String_Builder;
    /*
    print_to_builder(*builder, "\n// Database of all archetype data\n");
    print_to_builder(*builder, "ARCHETYPE_DATABASE :: struct {\n");
    
    for arch: metadata {
        print_to_builder(*builder, "\t%_Data :: struct {\n", arch.name);

		print_to_builder(*builder, "\t\tEntity_Component_Mask	: Bit_Field(MAX_ENTITY_COMPONENTS) = make_bit_field(MAX_ENTITY_COMPONENTS, u32.[0, 1, 2])\n");
		print_to_builder(*builder, "\t}\n");
    }
    print_to_builder(*builder, "}\n");
    */
    return builder_to_string(*builder);
}