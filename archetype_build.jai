#import "Basic";
#import "Compiler";
#import "String";
#import "Process";
#import "File";
#import "File_Utilities";
#import "Text_File_Handler";

ZECS_ARCHETYPES_GEN_PATH 	:: "src/ZECS/generated/ZECS_archetypes_gen.jai";

build_archetypes			: [..]Archetype_Build_Metadata;

arch_gen := false;
build :: () {
	set_build_options_dc(.{do_output=false});

	file_delete(ZECS_ARCHETYPES_GEN_PATH);
	
	w_generation := compiler_create_workspace("Archetype Generation Workspace");
	if !w_generation {
		print("Archetype Generation Workspace creation failed.\n");
		return;
	}

	

	archetypes_options := get_build_options(w_generation);

	args := archetypes_options.compile_time_command_line;  
    for args {                                         
        if it == {
            case "arch_gen";
                arch_gen = true;
        }
    }

	archetypes_options.output_type = .NO_OUTPUT;
	archetypes_options.backend = .X64;
	archetypes_options.array_bounds_check = .ON; 
    set_optimization(*archetypes_options, Optimization_Type.DEBUG, true);	
	set_build_options(archetypes_options, w_generation);
	
	
	generation_success := code_generation(w_generation);
	if !generation_success {
	 	print("ERROR: Code generation failed.\n");
        return;
	}
}

code_generation :: (w: Workspace) -> bool {
	compiler_begin_intercept(w);

	generated := false;
	add_build_file("src/bit_field.jai", w);
	add_build_file("H:/PBEMJai/src/zmath.jai", w);
	add_build_file("H:/PBEMJai/src/rotor.jai", w);
	add_build_file("src/ZECS/ZECS_build_types.jai", w);
	add_build_file("src/ZECS/ZECS_components.jai", w);
	add_build_file("src/ZECS/ZECS_archetypes.jai", w);
	add_build_file("src/ZECS/stub/ZECS_archetype_meta_stub.jai", w);
	add_build_file("src/ZECS/generated/ZECS_constants_gen.jai", w);
	add_build_file("src/ZECS/generated/ZECS_components_gen.jai", w);
	add_build_file("src/types.jai", w);
	if arch_gen {
        add_build_string("arch_gen :: true;", w);
    } else {
        add_build_string("arch_gen :: false;", w);
    }

	
	while true {                     
        message := compiler_wait_for_message();  
        if !message break; 
        
        if message.kind == {
            case .TYPECHECKED;
                typechecked := cast(*Message_Typechecked)message;
                gather_archetypes(typechecked, *build_archetypes);
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

generate_archetype_code :: (w: Workspace, archetypes: [..]Archetype_Build_Metadata){
    archetypes_file_builder: String_Builder;
	
	quick_sort(archetypes, compare_build_metadata);

	
	append(*archetypes_file_builder, generate_archetype_database(archetypes));
	append(*archetypes_file_builder, generate_archetype_index_lookup(archetypes));
	append(*archetypes_file_builder, generate_index_archetype_lookup(archetypes));
	append(*archetypes_file_builder, generate_component_storage_getter(archetypes));
	append(*archetypes_file_builder, generate_string_to_arch_type(get_archetype_names(archetypes)));
	append(*archetypes_file_builder, generate_archetype_component_index_getters(archetypes));
	append(*archetypes_file_builder, generate_entity_component_initializers(archetypes));
	append(*archetypes_file_builder, generate_entity_initializer_dispatch(archetypes));
	append(*archetypes_file_builder, generate_archetype_initialization(archetypes));

    
	write_entire_file(ZECS_ARCHETYPES_GEN_PATH, builder_to_string(*archetypes_file_builder));
	add_build_file(ZECS_ARCHETYPES_GEN_PATH, w);
	print("Generated ZECS archetypes file: %\n", ZECS_ARCHETYPES_GEN_PATH);
}

main :: () {}

#run build();

#load "src/ZECS/ZECS_build_types.jai";
#load "src/ZECS/ZECS_archetypes_meta.jai";
#load "src/types.jai";