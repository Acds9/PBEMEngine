#import "Basic";
#import "Compiler";
#import "String";
#import "Process";
#import "File";
#import "File_Utilities";
#import "Text_File_Handler";

ZECS_QUERIES_GEN_PATH		:: "ZECS/generated/ZECS_queries_gen.jai";

build_queries				: [..]Query_Build_Metadata;

build :: () {
	set_build_options_dc(.{do_output=false});

	file_delete(ZECS_QUERIES_GEN_PATH);
	
	w_generation := compiler_create_workspace("Query Generation Workspace");
	if !w_generation {
		print("Query Generation Workspace creation failed.\n");
		return;
	}

	archetypes_options := get_build_options(w_generation);
	archetypes_options.output_type = .NO_OUTPUT;
	archetypes_options.backend = .X64;
	archetypes_options.array_bounds_check = .ON; 
    set_optimization(*archetypes_options, Optimization_Type.DEBUG, true);	
	set_build_options(archetypes_options, w_generation);
	
	generation_success := code_generation(w_generation);
	if !generation_success {
	 	print("ERROR: Query generation failed.\n");
        return;
	}
}

code_generation :: (w: Workspace) -> bool {
	compiler_begin_intercept(w);

	generated := false;
	add_build_file("ZECS/ZECS_types.jai", w);
	add_build_file("ZECS/generated/ZECS_constants_gen.jai", w);
	add_build_file("ZECS/generated/ZECS_components_gen.jai", w);
	add_build_file("ZECS/generated/ZECS_archetypes_gen.jai", w);
	add_build_file("ZECS/ZECS_build_types.jai", w);
	add_build_file("ZECS/ZECS_storage.jai", w);
	add_build_file("ZECS/ZECS_components.jai", w);
	add_build_file("ZECS/ZECS_archetypes.jai", w);
	add_build_file("ZECS/ZECS_observers.jai", w);
	add_build_file("ZECS/ZECS_main.jai", w);

	while true {                     
        message := compiler_wait_for_message();  
        if !message break; 
        
        if message.kind == {
            case .TYPECHECKED;
                typechecked := cast(*Message_Typechecked)message;
				#load "ZECS/ZECS_build_types.jai";
                gather_queries(typechecked, *build_queries);
            case .PHASE;
                phase := cast(*Message_Phase) message;
                if phase.phase == .TYPECHECKED_ALL_WE_CAN && !generated {
                    generate_query_code(w, build_queries);
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
// TODO: dump the Archetype_Build_Metadata array into the archetypes_gen file and be done with it
generate_query_code :: (w: Workspace, query_metadata: []Query_Build_Metadata) {
	
	queries_file_builder: String_Builder;

	#load "ZECS/ZECS_queries_meta.jai";
	#load "ZECS/generated/ZECS_archetypes_gen.jai";
	#load "ZECS/generated/ZECS_constants_gen.jai";
	#load "ZECS/ZECS_components.jai";
	#load "ZECS/ZECS_storage.jai";
	#load "ZECS/ZECS_archetypes.jai";
	#load "ZECS/ZECS_main.jai";
	#load "ZECS/ZECS_types.jai";
	append(*queries_file_builder, generate_queries(archetype_metadata, query_metadata));
    
	write_entire_file(ZECS_QUERIES_GEN_PATH, builder_to_string(*queries_file_builder));
	add_build_file(ZECS_QUERIES_GEN_PATH, w);
	print("Generated ZECS queries file: %\n", ZECS_QUERIES_GEN_PATH);
	array_add(*generated_query_files, ZECS_QUERIES_GEN_PATH);
}

main :: () {}

#run build();