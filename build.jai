#import "Basic";
#import "Compiler";
#import "String";
#import "Process";
#load "ZECS/ZECS_components_meta.jai";
#load "ZECS/ZECS_archetypes_meta.jai";


success := false;

build :: () {
    w := compiler_create_workspace();                     
    if !w {
        print("Workspace creation failed.\n");
        return;
    }

	// Setup build options
    setup_build_options(w);
    
    // Start compilation
    compiler_begin_intercept(w);  
    add_source_files(w);
    
    // Process messages and generate code
    success = process_compilation(w);
	
	compiler_end_intercept(w);
    if success {            
        print("[SUCCESS!]\n");
        //run_command(sprint("%/%", target_options.output_path, target_options.output_executable_name));  
    }    
}

setup_build_options :: (w: Workspace) {
    target_options := get_build_options(w);  
    target_options.backend = .X64;
    set_optimization(*target_options, Optimization_Type.DEBUG, true);	
    target_options.array_bounds_check = .ON; 
    target_options.output_path = "bin";
    target_options.output_executable_name = "PBEM";    
    set_build_options(target_options, w);
}

add_source_files :: (w: Workspace) {
    add_build_file("main.jai", w);   
    add_build_file("ZECS/ZECS_main.jai", w);
    add_build_file("ZECS/ZECS_types.jai", w);
    add_build_file("ZECS/ZECS_components.jai", w);
}

process_compilation :: (w: Workspace) -> bool {
    entity_components 	: [..]string;
    arch_components   	: [..]string;
    tags              	: [..]string;

	archetypes			: [..]Archetype_Build_Metadata;

    generated := false;
    
    while true {                     
        message := compiler_wait_for_message();  
        if !message break; 
        
        if message.kind == {
            case .TYPECHECKED;
                gather_component_types(cast(*Message_Typechecked) message, *entity_components, *arch_components, *tags);
				found_archetypes := gather_archetypes(cast(*Message_Typechecked) message);
				
				if found_archetypes archetypes = found_archetypes;
            case .PHASE;
                phase := cast(*Message_Phase) message;
                if phase.phase == .TYPECHECKED_ALL_WE_CAN && !generated {
                    generate_all_code(w, entity_components, arch_components, tags, archetypes);
                    generated = true;
                }
                
            case .COMPLETE;          
                print(" >> %\n", <<message);
                message_complete := cast(*Message_Complete) message;  
                return message_complete.error_code == 0;
        }
    }
    
    return false;
}

gather_component_types :: (typechecked: *Message_Typechecked, entity_comps: *[..]string, arch_comps: *[..]string, tags: *[..]string) {
	x := typechecked.declarations;
    for typechecked.structs{
		info := it.expression.defined_type;
        
        if is_subclass_of(info, "Entity_Component") {
            if array_add_if_unique(entity_comps, info.name) {
                print("Detected entity component: %\n", info.name);
            }
        } else if is_subclass_of(info, "Archetype_Component") {
            if array_add_if_unique(arch_comps, info.name) {
                print("Detected archetype component: %\n", info.name);
            }
        } else if is_subclass_of(info, "Tag") {
            if array_add_if_unique(tags, info.name) {
                print("Detected tag: %\n", info.name);
            }
        }
    }
}

gather_archetypes :: (typechecked: *Message_Typechecked) -> [..]Archetype_Build_Metadata {
	archetypes : [..]Archetype_Build_Metadata;
	for typechecked.declarations {
        decl := it.expression;
        
        if decl.flags & .IS_CONSTANT {
            info := decl.type;
            if (info.type == .STRUCT) {
                struct_info := cast(*Type_Info_Struct) info;
                
                if struct_info.polymorph_source_struct && struct_info.polymorph_source_struct.name == "Archetype" {
                    
					archetype : Archetype_Build_Metadata;
					archetype.name = decl.name;
                    for member: struct_info.members {
                        if member.name == "entity_components" {
                            array_type := cast(*Type_Info_Array) member.type;
                            
                            // Create an Any pointing to the member data
                            any: Any;
                            any.type = member.type;
                            
                            // Get the value pointer - this depends on where the data actually is
                            if member.offset_into_constant_storage >= 0 {
                                any.value_pointer = struct_info.constant_storage.data + member.offset_into_constant_storage;
                            } else {
                                // Try using offset_in_bytes
                                any.value_pointer = struct_info.constant_storage.data + member.offset_in_bytes;
                            }
                            
                            // Now extract array data like print_array does
                            if array_type.array_type == .FIXED {
                                count := array_type.array_count;
                                data := any.value_pointer;  // For FIXED arrays, data is directly here
                                
                                for i: 0..count-1 {
                                    pointer := data + array_type.element_type.runtime_size * i;
                                    
                                    // Create Any for each element
                                    item: Any;
                                    item.type = array_type.element_type;
                                    item.value_pointer = pointer;
                                    
                                    // Now extract the Type (*Type_Info)
                                    type_ptr := (.*) cast(**Type_Info_Struct) item.value_pointer;
                                    if type_ptr {
										type := <<type_ptr;
										array_add(*archetype.entity_components, type.name);
                                    }
                                }
                            }
                        }
                    }
					print("Detected Archetype: %\n", archetype);
					array_add(*archetypes, archetype);
                }
            }
        }
    }

	return archetypes;
}

generate_all_code :: (w: Workspace, entity_comps: []string, arch_comps: []string, tags: []string, archetypes: []Archetype_Build_Metadata) {

	constants_code := generate_ZECS_constants(entity_comps.count, arch_comps.count, tags.count);
	add_build_string(constants_code, w);

	
    // Generate entity component switch
    if entity_comps.count > 0 {
        code := generate_component_switch(entity_comps, "get_entity_component_index", "get_entity_component_type", "get_entity_component_size");
        add_build_string(code, w);
        print("Generated entity component switch with % components\n", entity_comps.count);
    }
    
    // Generate archetype component switch
    if arch_comps.count > 0 {
        code := generate_component_switch(arch_comps, "get_archetype_component_index", "get_archetype_component_type", "get_archetype_component_size");
        add_build_string(code, w);
        print("Generated archetype component switch with % components\n", arch_comps.count);
    }
    
    // Generate tag switch
    if tags.count > 0 {
        code := generate_component_switch(tags, "get_tag_index", "get_tag_type", "");
        add_build_string(code, w);
        print("Generated tag switch with % tags\n", tags.count);
    }

	if archetypes.count > 0 {
		code := generate_archetype_switch(get_arch_names(archetypes), "get_arch_index");
		add_build_string(code, w);
		print("Generated archetype switch with % archetypes\n", archetypes.count);
		code = generate_archetype_initializer_switch(archetypes, "entity_initializer_switch");
		add_build_string(code, w);
		code = generate_archetype_initializers(archetypes);
		add_build_string(code, w);
		code = generate_archetype_e_c_storage_mappings(archetypes);
		add_build_string(code, w);
	}
}

main :: (){}

#run build();