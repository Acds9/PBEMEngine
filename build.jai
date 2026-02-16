#import "Basic";
#import "Compiler";
#import "String";
#import "Process";
#import "File";
#import "File_Utilities";
#import "Text_File_Handler";
JaiSymbols :: #import "Jai_Symbols";

DEBUG_BUILD :: true;
symbols: JaiSymbols.Symbols;

ORDER_EXECUTORS_PATH :: "src/ZAOSS/generated/order_gen.jai";

build :: () {
	file_delete("bin/PBEM.exe");
	file_delete(ORDER_EXECUTORS_PATH);

    w_final := compiler_create_workspace("Final Workspace");  
    if !w_final {
        print("Final Workspace creation failed.\n");
        return;
    }

	#load "src/ZAOSS/orders_meta.jai";
	//  Build options
   	final_options := get_build_options(w_final);  
    final_options.backend = .X64;
	optimization_type : Optimization_Type = ifx DEBUG_BUILD then .VERY_DEBUG else .VERY_OPTIMIZED;
    set_optimization(*final_options, optimization_type, DEBUG_BUILD);	
    final_options.array_bounds_check = .ON; 
    final_options.output_path = "bin";
	final_options.output_type = .EXECUTABLE;
    final_options.output_executable_name = "PBEM";  
	
	linker_args: [..]string;
    for final_options.additional_linker_arguments {
        array_add(*linker_args, it);
    }
    // vulkan memory allocator depends on this
    array_add(*linker_args, "libcpmt.lib");
	array_add(*linker_args, "advapi32.lib");
    final_options.additional_linker_arguments = linker_args;

    set_build_options(final_options, w_final);
    
	order_executor_headers : [..]*Code_Procedure_Header;
    // Start compilation
    compiler_begin_intercept(w_final);  
    add_source_files(w_final);
	generated : bool;
	while true {                     
        message := compiler_wait_for_message();  
        if !message break; 
        
        if message.kind == {
            case .TYPECHECKED;
                typechecked := cast(*Message_Typechecked)message;
                gather_order_executors(typechecked, *order_executor_headers);
            case .PHASE;
                phase := cast(*Message_Phase) message;
                if phase.phase == .TYPECHECKED_ALL_WE_CAN && !generated {
                    generate_order_code(w_final, *order_executor_headers);
                    generated = true;
                }
            case .COMPLETE;          
                print(" >> %\n", <<message);
                message_complete := cast(*Message_Complete) message;  
				compiler_end_intercept(w_final);
                return;
        }
    }
	compiler_end_intercept(w_final);

	/* For when symbols need updating
	while true {                     
        message := compiler_wait_for_message();  
        if !message break;
        
        if message.kind == {
            case .TYPECHECKED;
                typechecked := cast(*Message_Typechecked)message;
				JaiSymbols.add(*symbols, typechecked);
            case .COMPLETE;     
				JaiSymbols.write(*symbols);
				compiler_end_intercept(w_final);
        }
    }
	*/
}

generate_order_code :: (w: Workspace, headers: *[..]*Code_Procedure_Header) {
	orders_file_builder: String_Builder;
	append(*orders_file_builder, generate_order_executors(<<headers));
	
	write_entire_file(ORDER_EXECUTORS_PATH, builder_to_string(*orders_file_builder));
	add_build_file(ORDER_EXECUTORS_PATH, w);
	print("Generated ZECS components file: %\n", ORDER_EXECUTORS_PATH);
}

add_source_files :: (w: Workspace) {
    src_files := file_list("src", true, true);
	filtered_files : [..]string;
	for file: src_files {
		if ends_with(file, "_stub.jai") continue;	// Skip build stubs
		if ends_with(file, "_meta.jai") continue;	// Skip build meta files
		if ends_with(file, "_build.jai") continue;	// Skip build files (shouldn't be in src anyway)
		if !ends_with(file, ".jai") continue;		// Skip non code files
		array_add(*filtered_files, file);
	}
	for filtered_files {
		add_build_file(it, w);
	}
}

main :: (){}

#run build();
