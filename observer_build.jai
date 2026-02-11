#import "Basic";
#import "Compiler";
#import "String";
#import "Process";
#import "File";
#import "File_Utilities";
#import "Text_File_Handler";

ZECS_OBSERVER_GEN_PATH		:: "src/ZECS/generated/ZECS_observers_gen.jai";

build_observers				: [..]Observer_Build_Metadata;

build :: () {
	set_build_options_dc(.{do_output=false});

	file_delete(ZECS_OBSERVER_GEN_PATH);
	
	w_generation := compiler_create_workspace("Observer Generation Workspace");
	if !w_generation {
		print("Observer Generation Workspace creation failed.\n");
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
	 	print("ERROR: Observer generation failed.\n");
        return;
	}
}

code_generation :: (w: Workspace) -> bool {
	compiler_begin_intercept(w);

	generated := false;
	add_build_file("src/bit_field.jai", w);
	add_build_file("H:/PBEMJai/src/zmath.jai", w);
	add_build_file("H:/PBEMJai/src/rotor.jai", w);
	add_build_file("src/ZECS/generated/ZECS_constants_gen.jai", w);
	add_build_file("src/ZECS/generated/ZECS_components_gen.jai", w);
	add_build_file("src/ZECS/generated/ZECS_archetypes_gen.jai", w);
	add_build_file("src/ZECS/ZECS_build_types.jai", w);
	add_build_file("src/ZECS/ZECS_components.jai", w);
	add_build_file("src/ZECS/ZECS_archetypes.jai", w);
	add_build_file("src/ZECS/ZECS_observers.jai", w);
	add_build_file("src/ZECS/stub/ZECS_queries_meta_stub.jai", w);
	add_build_file("src/ZECS/stub/ZECS_observer_meta_stub.jai", w);
	add_build_file("src/types.jai", w);
	add_build_file("src/intel.jai", w);
	add_build_file("src/game_world.jai", w);

	while true {                     
        message := compiler_wait_for_message();  
        if !message break; 
        
        if message.kind == {
            case .TYPECHECKED;
                typechecked := cast(*Message_Typechecked)message;
				#load "src/ZECS/ZECS_build_types.jai";
                gather_observers(typechecked, *build_observers);
            case .PHASE;
                phase := cast(*Message_Phase) message;
                if phase.phase == .TYPECHECKED_ALL_WE_CAN && !generated {
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

generate_observer_code :: (w: Workspace, observer_metadata: []Observer_Build_Metadata) {
	
	observers_file_builder: String_Builder;
	
	#load "src/ZECS/generated/ZECS_archetypes_gen.jai";
	#load "src/ZECS/generated/ZECS_components_gen.jai";
	#load "src/ZECS/generated/ZECS_constants_gen.jai";
	#load "src/ZECS/ZECS_components.jai";
	#load "src/ZECS/ZECS_archetypes.jai";
	#load "src/bit_field.jai";
	#load "H:/PBEMJai/src/zmath.jai";
	#load "H:/PBEMJai/src/rotor.jai";
	#load "src/ZECS/stub/ZECS_queries_meta_stub.jai";
	#load "src/ZECS/ZECS_observers_meta.jai";
	#load "src/types.jai";
	#load "src/intel.jai";
	#load "src/game_world.jai";
	append(*observers_file_builder, generate_observers(observer_metadata));
    
	write_entire_file(ZECS_OBSERVER_GEN_PATH, builder_to_string(*observers_file_builder));
	add_build_file(ZECS_OBSERVER_GEN_PATH, w);
	print("Generated ZECS queries file: %\n", ZECS_OBSERVER_GEN_PATH);
}

main :: () {}

#run build();