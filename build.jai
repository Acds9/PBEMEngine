#import "Basic";
#import "Compiler";
#import "String";
#import "Process";
#import "File";
#import "Text_File_Handler";
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
		options := get_build_options(w);
        run_command(sprint("%/%", options.output_path, options.output_executable_name));  
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

generate_all_code :: (w: Workspace, entity_comps: []string, arch_comps: []string, tags: []string, archetypes: []Archetype_Build_Metadata) {

	constants_code := generate_ZECS_constants(entity_comps.count, arch_comps.count, tags.count);

	constants_file_builder: String_Builder;
	append(*constants_file_builder, constants_code);
	write_entire_file("ZECS/generated/ZECS_constants_gen.jai", builder_to_string(*constants_file_builder));
	add_build_file("ZECS/generated/ZECS_constants_gen.jai", w);
	print("Generated ZECS constants file: ZECS/generated/ZECS_constants_gen.jai\n");

    components_file_builder: String_Builder;
    if entity_comps.count > 0 {
        code := generate_component_switch(entity_comps, "get_entity_component_index", "get_entity_component_type", "get_entity_component_size");
        append(*components_file_builder, code);
        print("Generated entity component switch with % components\n", entity_comps.count);
    }
    
    if arch_comps.count > 0 {
        code := generate_component_switch(arch_comps, "get_archetype_component_index", "get_archetype_component_type", "get_archetype_component_size");
        append(*components_file_builder, code);
        print("Generated archetype component switch with % components\n", arch_comps.count);
    }
    
    if tags.count > 0 {
        code := generate_component_switch(tags, "get_tag_index", "get_tag_type", "");
        append(*components_file_builder, code);
        print("Generated tag switch with % tags\n", tags.count);
    }

	write_entire_file("ZECS/generated/ZECS_components_gen.jai", builder_to_string(*components_file_builder));
	add_build_file("ZECS/generated/ZECS_components_gen.jai", w);
	print("Generated ZECS components file: ZECS/generated/ZECS_components_gen.jai\n");

	archetypes_file_builder: String_Builder;
	if archetypes.count > 0 {
		code := generate_archetype_code(archetypes);
		append(*archetypes_file_builder, code);
	}

	write_entire_file("ZECS/generated/ZECS_archetypes_gen.jai", builder_to_string(*archetypes_file_builder));
	add_build_file("ZECS/generated/ZECS_archetypes_gen.jai", w);
	print("Generated ZECS archetypes file: ZECS/generated/ZECS_archetypes_gen.jai\n");
}

main :: (){}

#run build();