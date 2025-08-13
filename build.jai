#import "Basic";
#import "Compiler";
#import "String";
#import "Process";
#import "File";
#import "File_Utilities";
#import "Text_File_Handler";

#load	"ZECS/ZECS_types.jai";
#load	"ZECS/ZECS_build_types.jai";
#load	"ZECS/ZECS_components_meta.jai";
#load	"ZECS/ZECS_archetypes_meta.jai";

ZECS_CONSTANTS_GEN_PATH 	:: "ZECS/generated/ZECS_constants_gen.jai";
ZECS_COMPONENTS_GEN_PATH 	:: "ZECS/generated/ZECS_components_gen.jai";
ZECS_ARCHETYPES_GEN_PATH 	:: "ZECS/generated/ZECS_archetypes_gen.jai";
ZECS_QUERIES_GEN_PATH		:: "ZECS/generated/ZECS_queries_gen.jai";
ZECS_OBSERVERS_GEN_PATH		:: "ZECS/generated/ZECS_observers_gen.jai";

generated_constants_files 	: [..]string;
generated_component_files 	: [..]string;
generated_archetype_files 	: [..]string;
generated_query_files 		: [..]string;
generated_observer_files	: [..]string;

build_entity_components		: [..]string;
build_archetype_components	: [..]string;
build_tags					: [..]string;
build_archetypes			: [..]Archetype_Build_Metadata;
build_queries				: [..]Query_Build_Metadata;
build_observers				: [..]Observer_Build_Metadata;

build :: () {

	set_build_options_dc(.{do_output=false});
	
	file_delete("bin/PBEM.exe");
	file_delete(ZECS_CONSTANTS_GEN_PATH);
	file_delete(ZECS_COMPONENTS_GEN_PATH);
	file_delete(ZECS_ARCHETYPES_GEN_PATH);
	file_delete(ZECS_QUERIES_GEN_PATH);
	file_delete(ZECS_OBSERVERS_GEN_PATH);

    // Clear the arrays
    array_reset(*generated_constants_files);
    array_reset(*generated_component_files);
    array_reset(*generated_archetype_files);
    array_reset(*generated_query_files);
	array_reset(*generated_observer_files);
	
	w_generation := compiler_create_workspace("Code Generation Workspace");
	if !w_generation {
		print("Code Generation Workspace creation failed.\n");
		return;
	}

	components_options := get_build_options(w_generation);
	components_options.output_type = .NO_OUTPUT;
	components_options.backend = .X64;
	components_options.array_bounds_check = .ON; 
    set_optimization(*components_options, Optimization_Type.DEBUG, true);	
	set_build_options(components_options, w_generation);
	
	generation_success := code_generation(w_generation);
	if !generation_success {
	 	print("ERROR: Code generation failed.\n");
        return;
	}

    w_final := compiler_create_workspace("Final Workspace");  
    if !w_final {
        print("Final Workspace creation failed.\n");
        return;
    }

	//  Build options
   	final_options := get_build_options(w_final);  
    final_options.backend = .X64;
    set_optimization(*final_options, Optimization_Type.VERY_DEBUG, true);	
    final_options.array_bounds_check = .ON; 
    final_options.output_path = "bin";
	final_options.output_type = .EXECUTABLE;
    final_options.output_executable_name = "PBEM";    
    set_build_options(final_options, w_final);
    

    // Start compilation
    compiler_begin_intercept(w_final);  
    add_source_files(w_final);
	compiler_end_intercept(w_final);

}

code_generation :: (w: Workspace) -> bool {
	compiler_begin_intercept(w);

	generated := false;
	add_build_file("ZECS/ZECS_types.jai", w);
	add_build_file("ZECS/ZECS_build_types.jai", w);
	add_build_file("ZECS/ZECS_components.jai", w);
	add_build_file("ZECS/ZECS_archetypes.jai", w);
	add_build_file("ZECS/ZECS_queries.jai", w);
	add_build_file("ZECS/ZECS_observers.jai", w);
	add_build_file("ZECS/ZECS_main.jai", w);
	
	while true {                     
        message := compiler_wait_for_message();  
        if !message break; 
        
        if message.kind == {
            case .TYPECHECKED;
                typechecked := cast(*Message_Typechecked)message;
                build_entity_components, build_archetype_components, build_tags = 	gather_component_types(typechecked);
				build_archetypes =													gather_archetypes(typechecked);
				build_queries = 													gather_queries(typechecked);
				build_observers = 													gather_observers(typechecked);
            case .PHASE;
                phase := cast(*Message_Phase) message;
                if phase.phase == .TYPECHECKED_ALL_WE_CAN && !generated {
                    generate_component_code(w, build_entity_components, generated_archetype_files, build_tags);
					generate_archetype_code(w, build_archetypes);
					generate_query_code(w, build_queries);
					generate_observer_code(w, build_observers);
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
/*
// TODO: having a single workspace wont work, archetypes cant depend on the components gen if it hasn't been written yet 
// The phases the AI suggested might not be a bad idea
// Maybe all the gather functions should be in the same file? They don't depend on each-other at all
component_compilation :: (w: Workspace) -> bool {
	compiler_begin_intercept(w);

	generated := false;

	while true {                     
        message := compiler_wait_for_message();  
        if !message break; 
        
        if message.kind == {
            case .TYPECHECKED;
				typechecked := cast(*Message_Typechecked)message;
                build_entity_components, build_arch_components, build_tags = 	gather_component_types(typechecked);
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
*/
generate_component_code :: (w: Workspace, entity_comps: []string, arch_comps: []string, tags: []string){
	constants_file_builder: String_Builder;

	constants_code := generate_ZECS_constants(entity_comps.count, arch_comps.count, tags.count); // Maybe this shouldn't be here?
	append(*constants_file_builder, constants_code);
	write_entire_file(ZECS_CONSTANTS_GEN_PATH, builder_to_string(*constants_file_builder));
	add_build_file(ZECS_CONSTANTS_GEN_PATH, w);
	print("Generated ZECS constants file: %\n", ZECS_CONSTANTS_GEN_PATH);
	array_add(*generated_constants_files, ZECS_CONSTANTS_GEN_PATH);

    components_file_builder: String_Builder;

	code := generate_component_switch(entity_comps);
	append(*components_file_builder, code);
    
	code = generate_string_to_entity_comp_type(entity_comps);
	append(*components_file_builder, code);
	code = generate_string_to_arch_comp_type(arch_comps);
	append(*components_file_builder, code);

	code_string := builder_to_string(*components_file_builder);
	add_build_string(code_string, w);
	write_entire_file(ZECS_COMPONENTS_GEN_PATH, builder_to_string(*components_file_builder));
	//add_build_file(ZECS_COMPONENTS_GEN_PATH, w);
	print("Generated ZECS components file: %\n", ZECS_COMPONENTS_GEN_PATH);
	array_add(*generated_component_files, ZECS_COMPONENTS_GEN_PATH);
}
/*
archetype_compilation :: (w: Workspace) -> bool {
	compiler_begin_intercept(w);

	add_build_file("ZECS/ZECS_types.jai", w);
	add_build_file("ZECS/ZECS_components.jai", w);
	add_build_file("ZECS/ZECS_archetypes.jai", w);
	for generated_constants_files {
		add_build_file(it, w);
	}
	for generated_component_files {
		add_build_file(it, w);
	}

	generated := false;

	while true {                     
        message := compiler_wait_for_message();  
        if !message break; 
        
        if message.kind == {
			case .TYPECHECKED;
                found := gather_archetypes(cast(*Message_Typechecked) message);
                if found.count > 0 build_archetypes = found;
            case .PHASE;
                phase := cast(*Message_Phase) message;
                if phase.phase == .TYPECHECKED_ALL_WE_CAN && !generated {
                    generate_archetype_code(w, build_archetypes);
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
*/
generate_archetype_code :: (w: Workspace, archetypes: []Archetype_Build_Metadata) {
	archetypes_file_builder: String_Builder;

	append(*archetypes_file_builder, generate_archetype_database(archetypes));
	append(*archetypes_file_builder, generate_archetype_initializers(archetypes));
	append(*archetypes_file_builder, generate_archetype_initializer_getter(archetypes));

	// Core lookup functions
	append(*archetypes_file_builder, generate_archetype_index_lookup(archetypes));
	append(*archetypes_file_builder, generate_index_archetype_lookup(archetypes));
	append(*archetypes_file_builder, generate_component_storage_getter(archetypes));
	append(*archetypes_file_builder, generate_string_to_arch_type(get_archetype_names(archetypes)));
	append(*archetypes_file_builder, generate_archetype_component_index_getters(archetypes));
    
	// Entity initialization
	append(*archetypes_file_builder, generate_entity_component_initializers(archetypes));
	append(*archetypes_file_builder, generate_entity_initializer_dispatch(archetypes));

    
	write_entire_file(ZECS_ARCHETYPES_GEN_PATH, builder_to_string(*archetypes_file_builder));
	add_build_file(ZECS_ARCHETYPES_GEN_PATH, w);
	print("Generated ZECS archetypes file: %\n", ZECS_ARCHETYPES_GEN_PATH);
	array_add(*generated_archetype_files, ZECS_ARCHETYPES_GEN_PATH);
}
/*
query_compilation :: (w: Workspace) -> bool {
	compiler_begin_intercept(w);

	add_build_file("ZECS/ZECS_types.jai", w);
	add_build_file("ZECS/ZECS_components.jai", w);
	add_build_file("ZECS/ZECS_archetypes.jai", w);
	add_build_file("ZECS/ZECS_queries.jai", w);
	add_build_file("ZECS/ZECS_observers.jai", w);
	add_build_file("ZECS/ZECS_main.jai", w);
	for generated_constants_files {
		add_build_file(it, w);
	}
	for generated_component_files {
		add_build_file(it, w);
	}
	for generated_archetype_files {
		add_build_file(it, w);
	}

	generated := false;

	while true {                     
        message := compiler_wait_for_message();  
        if !message break; 
        
        if message.kind == {
			case .TYPECHECKED;
                found := gather_queries(cast(*Message_Typechecked) message);
                if found.count > 0 build_queries = found;
            case .PHASE;
                phase := cast(*Message_Phase) message;
                if phase.phase == .TYPECHECKED_ALL_WE_CAN && !generated {
                    generate_query_code(w);
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
*/
generate_query_code :: (w: Workspace, metadata: []Query_Build_Metadata) {
	#load "ZECS/ZECS_queries_meta.jai";
	queries_file_builder: String_Builder;

	append(*queries_file_builder, generate_queries(build_archetypes, metadata));
    
	write_entire_file(ZECS_QUERIES_GEN_PATH, builder_to_string(*queries_file_builder));
	add_build_file(ZECS_QUERIES_GEN_PATH, w);
	print("Generated ZECS queries file: %\n", ZECS_QUERIES_GEN_PATH);
	array_add(*generated_query_files, ZECS_QUERIES_GEN_PATH);
}
/*
observer_compilation :: (w: Workspace) -> bool {
	compiler_begin_intercept(w);

	add_build_file("ZECS/ZECS_types.jai", w);
	add_build_file("ZECS/ZECS_components.jai", w);
	add_build_file("ZECS/ZECS_archetypes.jai", w);
	add_build_file("ZECS/ZECS_observers.jai", w);
	add_build_file("ZECS/ZECS_main.jai", w);
	for generated_constants_files {
		add_build_file(it, w);
	}
	for generated_component_files {
		add_build_file(it, w);
	}
	for generated_archetype_files {
		add_build_file(it, w);
	}

	generated := false;

	while true {                     
        message := compiler_wait_for_message();  
        if !message break; 
        
        if message.kind == {
			case .TYPECHECKED;
                found := gather_observers(cast(*Message_Typechecked) message);
                if found.count > 0 build_observers = found;
            case .PHASE;
                phase := cast(*Message_Phase) message;
                if phase.phase == .TYPECHECKED_ALL_WE_CAN && !generated {
                    generate_observer_code(w);
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
*/
generate_observer_code :: (w: Workspace, metadata: []Observer_Build_Metadata) {
	#load "ZECS/ZECS_observers_meta.jai";
	observers_file_builder: String_Builder;

	append(*observers_file_builder, generate_observers(build_archetypes, metadata));
    
	write_entire_file(ZECS_OBSERVERS_GEN_PATH, builder_to_string(*observers_file_builder));
	add_build_file(ZECS_OBSERVERS_GEN_PATH, w);
	print("Generated ZECS observers file: %\n", ZECS_OBSERVERS_GEN_PATH);
	array_add(*generated_observer_files, ZECS_OBSERVERS_GEN_PATH);
}

add_source_files :: (w: Workspace) {
    add_build_file("ZECS/ZECS_types.jai", w);
    add_build_file("ZECS/ZECS_components.jai", w);
	add_build_file("ZECS/ZECS_archetypes.jai", w);
	add_build_file("ZECS/ZECS_components_meta.jai", w);
	add_build_file("ZECS/ZECS_observers.jai", w);
	add_build_file("ZECS/ZECS_main.jai", w);
	add_build_file("main.jai", w);  
	
	for generated_constants_files {
		add_build_file(it, w);
	}
	for generated_component_files {
		add_build_file(it, w);
	}
	for generated_archetype_files {
		add_build_file(it, w);
	}
	for generated_query_files {
		add_build_file(it, w);
	}
	for generated_observer_files {
		add_build_file(it, w);
	}
}

main :: (){}

#run build();
