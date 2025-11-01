#import "Basic";
#import "Compiler";
#import "String";
#import "Process";
#import "File";
#import "File_Utilities";
#import "Text_File_Handler";

ZECS_CONSTANTS_GEN_PATH 	:: "src/ZECS/generated/ZECS_constants_gen.jai";
ZECS_COMPONENTS_GEN_PATH 	:: "src/ZECS/generated/ZECS_components_gen.jai";
generated_constants_files 	: [..]string;
generated_component_files 	: [..]string;


build :: () {
	set_build_options_dc(.{do_output=false});

	file_delete(ZECS_CONSTANTS_GEN_PATH);
	file_delete(ZECS_COMPONENTS_GEN_PATH);
	
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
}

code_generation :: (w: Workspace) -> bool {
	compiler_begin_intercept(w);

	generated := false;
	add_build_file("src/ZECS/ZECS_types.jai", w);
	add_build_file("H:/PBEMJai/src/zmath.jai", w);
	add_build_file("src/ZECS/ZECS_build_types.jai", w);
	add_build_file("src/ZECS/ZECS_components.jai", w);

	build_entity_components		: [..]string;
	build_archetype_components	: [..]string;
	build_tags					: [..]string;
	
	while true {                     
        message := compiler_wait_for_message();  
        if !message break; 
        
        if message.kind == {
            case .TYPECHECKED;
                typechecked := cast(*Message_Typechecked)message;
				#load "src/ZECS/ZECS_build_types.jai";
                gather_component_types(typechecked, *build_entity_components, *build_archetype_components, *build_tags);
            case .PHASE;
                phase := cast(*Message_Phase) message;
                if phase.phase == .TYPECHECKED_ALL_WE_CAN && !generated {
                    generate_component_code(w, build_entity_components, build_archetype_components, build_tags);
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

generate_component_code :: (w: Workspace, entity_comps: []string, arch_comps: []string, tags: []string){
	constants_file_builder: String_Builder;

	append(*constants_file_builder, generate_ZECS_constants(entity_comps.count, arch_comps.count, tags.count));
	write_entire_file(ZECS_CONSTANTS_GEN_PATH, builder_to_string(*constants_file_builder));
	add_build_file(ZECS_CONSTANTS_GEN_PATH, w);
	print("Generated ZECS constants file: %\n", ZECS_CONSTANTS_GEN_PATH);
	array_add(*generated_constants_files, ZECS_CONSTANTS_GEN_PATH);

	quick_sort(entity_comps, compare_strings);
	quick_sort(arch_comps, compare_strings);
	quick_sort(tags, compare_strings);

    components_file_builder: String_Builder;
	
	append(*components_file_builder, generate_file_loads());
	append(*components_file_builder, generate_entity_component_switches(entity_comps));
	append(*components_file_builder, generate_archetype_component_switches(arch_comps));
	append(*components_file_builder, generate_string_to_entity_comp_type(entity_comps));
	append(*components_file_builder, generate_string_to_arch_comp_type(arch_comps));
	
	write_entire_file(ZECS_COMPONENTS_GEN_PATH, builder_to_string(*components_file_builder));
	add_build_file(ZECS_COMPONENTS_GEN_PATH, w);
	print("Generated ZECS components file: %\n", ZECS_COMPONENTS_GEN_PATH);
	array_add(*generated_component_files, ZECS_COMPONENTS_GEN_PATH);
}

main :: () {}

#run build();

#load "src/ZECS/ZECS_components_meta.jai";