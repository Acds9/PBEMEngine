#import "Basic";
#import "Compiler";
#import "String";
#import "Process";
#import "File";
#import "Text_File_Handler";
#load "ZECS/ZECS_build_types.jai";

success := false;

ZECS_CONSTANTS_GEN_PATH :: "ZECS/generated/ZECS_constants_gen.jai";
ZECS_COMPONENTS_GEN_PATH :: "ZECS/generated/ZECS_components_gen.jai";
ZECS_ARCHETYPES_GEN_PATH :: "ZECS/generated/ZECS_archetypes_gen.jai";

generated_constants_files : [..]string;
generated_component_files : [..]string;
generated_archetype_files : [..]string;

build :: () {

	w_components := compiler_create_workspace("Component Workspace");
	if !w_components {
		print("Component Workspace creation failed.\n");
		return;
	}

	component_w_success := component_compilation(w_components);
	if component_w_success print("Component workspace build SUCCESS\n");

	w_archetypes := compiler_create_workspace("Archetype Workspace");
	if !w_archetypes {
		print("Archetype Workspace creation failed\n");
		return;
	}

	archetype_w_success := archetype_compilation(w_archetypes);
	if archetype_w_success print("Archetype workspace build SUCCESS\n");


    w := compiler_create_workspace("Final Workspace");                     
    if !w {
        print("Workspace creation failed.\n");
        return;
    }

	//  Build options
   	final_options := get_build_options(w);  
    final_options.backend = .X64;
    set_optimization(*final_options, Optimization_Type.DEBUG, true);	
    final_options.array_bounds_check = .ON; 
    final_options.output_path = "bin";
	final_options.output_type = .EXECUTABLE;
    final_options.output_executable_name = "PBEM";    
    set_build_options(final_options, w);
    
    // Start compilation
    compiler_begin_intercept(w);  
    add_source_files(w);
	compiler_end_intercept(w);
    if component_w_success && archetype_w_success {            
        print("[SUCCESS!]\n");
		options := get_build_options(w);
		exe_path := sprint("%/%", options.output_path, options.output_executable_name);
        run_command(exe_path);  
		print("Running %\n", exe_path);
    }    
}

component_compilation :: (w: Workspace) -> bool {
	components_options := get_build_options(w);
	components_options.output_type = .NO_OUTPUT;
	components_options.backend = .X64;
	components_options.array_bounds_check = .ON; 
    set_optimization(*components_options, Optimization_Type.DEBUG, true);	
	set_build_options(components_options, w);

	compiler_begin_intercept(w);

	add_build_file("ZECS/ZECS_types.jai", w);
	add_build_file("ZECS/ZECS_components.jai", w);

	entity_components 	: [..]string;
    arch_components   	: [..]string;
    tags              	: [..]string;

	generated := false;

	while true {                     
        message := compiler_wait_for_message();  
        if !message break; 
        
        if message.kind == {
            case .TYPECHECKED;
                gather_component_types(cast(*Message_Typechecked) message, *entity_components, *arch_components, *tags);
            case .PHASE;
                phase := cast(*Message_Phase) message;
                if phase.phase == .TYPECHECKED_ALL_WE_CAN && !generated {
                    generate_component_code(w, entity_components, arch_components, tags);
                    generated = true;
                }
                
            case .COMPLETE;          
                print(" >> %\n", <<message);
                message_complete := cast(*Message_Complete) message;  
				compiler_end_intercept(w);
                return message_complete.error_code == 0;
        }
    }
	compiler_end_intercept(w);
	return false;
}

generate_component_code :: (w: Workspace, entity_comps: []string, arch_comps: []string, tags: []string) {
	#load "ZECS/ZECS_types.jai";
	#load "ZECS/ZECS_components.jai";
	#load "ZECS/ZECS_components_meta.jai";
	constants_file_builder: String_Builder;

	constants_code := generate_ZECS_constants(entity_comps.count, arch_comps.count, tags.count); // Maybe this shouldn't be here?
	append(*constants_file_builder, constants_code);
	write_entire_file(ZECS_CONSTANTS_GEN_PATH, builder_to_string(*constants_file_builder));
	add_build_file(ZECS_CONSTANTS_GEN_PATH, w);
	print("Generated ZECS constants file: %\n", ZECS_CONSTANTS_GEN_PATH);
	array_add(*generated_constants_files, ZECS_CONSTANTS_GEN_PATH);

    components_file_builder: String_Builder;
    
	//append(*components_file_builder, "#load \"../ZECS_components.jai\";\n");
	
	code := generate_component_switch(entity_comps, "get_entity_component_index", "get_entity_component_type", "get_entity_component_size");
	append(*components_file_builder, code);
	
	code = generate_component_switch(arch_comps, "get_archetype_component_index", "get_archetype_component_type", "get_archetype_component_size");
	append(*components_file_builder, code);
    
	code = generate_component_switch(tags, "get_tag_index", "get_tag_type", "");
	append(*components_file_builder, code);
    
	code = generate_string_to_entity_comp_type(entity_comps);
	append(*components_file_builder, code);
	code = generate_string_to_arch_comp_type(arch_comps);
	append(*components_file_builder, code);

	write_entire_file(ZECS_COMPONENTS_GEN_PATH, builder_to_string(*components_file_builder));
	add_build_file(ZECS_COMPONENTS_GEN_PATH, w);
	print("Generated ZECS components file: %\n", ZECS_COMPONENTS_GEN_PATH);
	array_add(*generated_component_files, ZECS_COMPONENTS_GEN_PATH);
}

archetype_compilation :: (w: Workspace) -> bool {
	components_options := get_build_options(w);
	components_options.output_type = .NO_OUTPUT;
	components_options.backend = .X64;
	components_options.array_bounds_check = .ON; 
    set_optimization(*components_options, Optimization_Type.DEBUG, true);	
	set_build_options(components_options, w);

	compiler_begin_intercept(w);

	add_build_file("ZECS/ZECS_types.jai", w);
	add_build_file("ZECS/ZECS_components.jai", w);
	add_build_file("ZECS/ZECS_archetypes.jai", w);
	add_build_file("ZECS/ZECS_main.jai", w);
	for generated_constants_files {
		add_build_file(it, w);
	}
	for generated_component_files {
		add_build_file(it, w);
	}

	archetypes	: [..]Archetype_Build_Metadata;

	generated := false;

	while true {                     
        message := compiler_wait_for_message();  
        if !message break; 
        
        if message.kind == {
			case .TYPECHECKED;
                found := gather_archetypes(cast(*Message_Typechecked) message);
                if found.count > 0 archetypes = found;
            case .PHASE;
                phase := cast(*Message_Phase) message;
                if phase.phase == .TYPECHECKED_ALL_WE_CAN && !generated {
                    generate_archetype_code(w, archetypes);
                    generated = true;
                }
                
            case .COMPLETE;          
                print(" >> %\n", <<message);
                message_complete := cast(*Message_Complete) message;  
				compiler_end_intercept(w);
                return message_complete.error_code == 0;
        }
    }
	compiler_end_intercept(w);
	return false;
}

generate_archetype_code :: (w: Workspace, archetypes: []Archetype_Build_Metadata) {
	#load "ZECS/ZECS_archetypes_meta.jai";
	#load "ZECS/generated/ZECS_constants_gen.jai";
	archetypes_file_builder: String_Builder;

	append(*archetypes_file_builder, generate_archetype_database(archetypes));
	append(*archetypes_file_builder, generate_archetype_initializers(archetypes));
	append(*archetypes_file_builder, generate_archetype_initializer_getter(archetypes));

	// Core lookup functions
	append(*archetypes_file_builder, generate_archetype_index_lookup(archetypes));
	append(*archetypes_file_builder, generate_index_archetype_lookup(archetypes));
	append(*archetypes_file_builder, generate_component_storage_getter(archetypes));
    
	// Entity initialization
	append(*archetypes_file_builder, generate_entity_component_initializers(archetypes));
	append(*archetypes_file_builder, generate_entity_initializer_dispatch(archetypes));

    
	write_entire_file(ZECS_ARCHETYPES_GEN_PATH, builder_to_string(*archetypes_file_builder));
	add_build_file(ZECS_ARCHETYPES_GEN_PATH, w);
	print("Generated ZECS archetypes file: %\n", ZECS_ARCHETYPES_GEN_PATH);
	array_add(*generated_archetype_files, ZECS_ARCHETYPES_GEN_PATH);
}

add_source_files :: (w: Workspace) {
    add_build_file("main.jai", w);   
    add_build_file("ZECS/ZECS_main.jai", w);
    add_build_file("ZECS/ZECS_types.jai", w);
    add_build_file("ZECS/ZECS_components.jai", w);
	add_build_file("ZECS/ZECS_archetypes.jai", w);
	add_build_file("ZECS/ZECS_components_meta.jai", w);

	for generated_constants_files {
		add_build_file(it, w);
	}
	for generated_component_files {
		add_build_file(it, w);
	}
	for generated_archetype_files {
		add_build_file(it, w);
		print("Addec arch file: %\n", it);
	}
	
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
						any: Any;
						any.type = member.type;
    
						if(member.offset_into_constant_storage >= 0) {
							any.value_pointer = info.constant_storage.data + member.offset_into_constant_storage;
						} else {
							continue; // No valid offset
						}
    
						// The "array" is just the raw bytes of the u64 enum value
						tags_value := <<cast(*u64)any.value_pointer;
						archetype.tags = tags_value;
    
						print("Extracted TAGS value: %\n", tags_value);
					}
					else if (starts_with(member.name, "DEFAULT_")) {
						_,_,comp_name := split_from_left(member.name, "_");  // Skip "DEFAULT_"

						default_value: Archetype_Component_Default;
						default_value.comp_type_name = comp_name;
						default_value.data_type = member.type;
						default_value.data_ptr = info.constant_storage.data + member.offset_into_constant_storage;
						default_value.data_size = cast(u32)member.type.runtime_size;

						array_add(*archetype.a_c_defaults, default_value);
					}
					else if (member.name == "CHUNK_SIZE") {
						chunk_value := <<cast(*u32)(info.constant_storage.data + member.offset_into_constant_storage);

						archetype.chunk_size = chunk_value;
					}
				}
			}
			array_add(*archetypes, archetype);
        }
    }
	return archetypes;
}



main :: (){}

#run build();