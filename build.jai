#import "Basic";
#import "Compiler";
#import "String";
#import "Process";
#import "File";
#import "File_Utilities";
#import "Text_File_Handler";

DEBUG_BUILD :: true;

build :: () {
	
	file_delete("bin/PBEM.exe");

    w_final := compiler_create_workspace("Final Workspace");  
    if !w_final {
        print("Final Workspace creation failed.\n");
        return;
    }
	
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
    final_options.additional_linker_arguments = linker_args;

    set_build_options(final_options, w_final);
    

    // Start compilation
    compiler_begin_intercept(w_final);  
    add_source_files(w_final);
	compiler_end_intercept(w_final);
	
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
