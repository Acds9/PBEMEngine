#import "Basic";
#import "Compiler";
#import "String";
#import "Process";
#import "File";
#import "File_Utilities";
#import "Text_File_Handler";
JaiSymbols :: #import "Jai_Symbols";

DEBUG_BUILD :: true;

// Generated file paths
ORDER_EXECUTORS_PATH     :: "src/ZAOSS/generated/order_gen.jai";
STRUCT_SERIALIZERS_PATH  :: "src/ZAOSS/generated/serialization_gen.jai";
ZECS_CONSTANTS_GEN_PATH  :: "src/ZECS/generated/ZECS_constants_gen.jai";
ZECS_COMPONENTS_GEN_PATH :: "src/ZECS/generated/ZECS_components_gen.jai";
ZECS_ARCHETYPES_GEN_PATH :: "src/ZECS/generated/ZECS_archetypes_gen.jai";
ZECS_QUERIES_GEN_PATH    :: "src/ZECS/generated/ZECS_queries_gen.jai";
ZECS_OBSERVERS_GEN_PATH  :: "src/ZECS/generated/ZECS_observers_gen.jai";

// Gathered data that persists across phases
build_context	: Build_Context;

build :: () {
	set_build_options_dc(.{do_output=false});

	// Clean generated files
	file_delete("bin/PBEM.exe");
	file_delete(ORDER_EXECUTORS_PATH);
	file_delete(STRUCT_SERIALIZERS_PATH);
	file_delete(ZECS_CONSTANTS_GEN_PATH);
	file_delete(ZECS_COMPONENTS_GEN_PATH);
	file_delete(ZECS_ARCHETYPES_GEN_PATH);

	w := compiler_create_workspace("Target Program");
	if !w {
		print("Workspace creation failed.\n");
		return;
	}

	options := get_build_options(w);
	options.backend = .X64;
	optimization_type : Optimization_Type = ifx DEBUG_BUILD then .VERY_DEBUG else .VERY_OPTIMIZED;
	set_optimization(*options, optimization_type, DEBUG_BUILD);
	options.array_bounds_check = .ON;
	options.output_path = "bin";
	options.output_type = .EXECUTABLE;
	options.output_executable_name = "PBEM";

	linker_args: [..]string;
	for options.additional_linker_arguments array_add(*linker_args, it);
	array_add(*linker_args, "libcpmt.lib");
	array_add(*linker_args, "advapi32.lib");
	options.additional_linker_arguments = linker_args;

	set_build_options(options, w);

	order_executor_headers : [..]*Code_Procedure_Header;
	structs_to_serialize   : [..]*Type_Info_Struct;

	compiler_begin_intercept(w);
	add_source_files(w);

	generated := false;
	while true {
		message := compiler_wait_for_message();
		if !message break;
		if message.kind == {
			case .TYPECHECKED;
				typechecked := cast(*Message_Typechecked) message;
				gather_component_types(typechecked, *build_context);
				gather_archetypes(typechecked, *build_context);
				gather_queries(typechecked, *build_context);
				gather_observers(typechecked, *build_context);
				gather_order_executors(typechecked, *order_executor_headers);
				gather_structs_to_serialize(typechecked, *structs_to_serialize);
			case .PHASE;
				phase := cast(*Message_Phase) message;
				if phase.phase == .TYPECHECKED_ALL_WE_CAN && !generated {
					// Generate all files in dependency order.
					// All #placeholder identifiers in source files get filled
					// by the generated files added to this same workspace.
					generate_constants_code(w);
					generate_component_code(w);
					generate_archetype_code(w);
					generate_query_code(w);
					generate_observer_code(w);
					generate_order_code(w, *order_executor_headers);
					generate_serialization_code(w, *structs_to_serialize);
					generated = true;
				}
			case .COMPLETE;
				print(" >> %\n", <<message);
				compiler_end_intercept(w);
				return;
		}
	}
	compiler_end_intercept(w);
}

// Generated files are added explicitly so each phase only sees what it should.
add_source_files :: (w: Workspace) {
	src_files := file_list("src", true, true);
	for file: src_files {
		if ends_with(file, "_stub.jai") continue;
		if ends_with(file, "_meta.jai") continue;
		if ends_with(file, "_build.jai") continue;
		if ends_with(file, "_gen.jai")  continue;
		if !ends_with(file, ".jai") continue;
		add_build_file(file, w);
	}
}

// Code Generation 

generate_order_code :: (w: Workspace, headers: *[..]*Code_Procedure_Header) {
	orders_file_builder: String_Builder;
	append(*orders_file_builder, generate_order_executors(<<headers));
	write_entire_file(ORDER_EXECUTORS_PATH, builder_to_string(*orders_file_builder));
	add_build_file(ORDER_EXECUTORS_PATH, w);
	print("Generated ZAOSS order file: %\n", ORDER_EXECUTORS_PATH);
}

generate_serialization_code :: (w: Workspace, structs: *[..]*Type_Info_Struct) {
	print("Count: %\n", structs.count);
	serialization_file_builder: String_Builder;
	append(*serialization_file_builder, generate_struct_serializers(<<structs));
	append(*serialization_file_builder, generate_struct_deserializers(<<structs));
	write_entire_file(STRUCT_SERIALIZERS_PATH, builder_to_string(*serialization_file_builder));
	add_build_file(STRUCT_SERIALIZERS_PATH, w);
	print("Generated ZAOSS serializer file: %\n", STRUCT_SERIALIZERS_PATH);
}

generate_constants_code :: (w: Workspace) {
	constants_file_builder: String_Builder;
	append(*constants_file_builder, generate_ZECS_constants(*build_context));
	write_entire_file(ZECS_CONSTANTS_GEN_PATH, builder_to_string(*constants_file_builder));
	add_build_file(ZECS_CONSTANTS_GEN_PATH, w);
	print("Generated ZECS constants file: %\n", ZECS_CONSTANTS_GEN_PATH);
}

generate_component_code :: (w: Workspace) {
	components_file_builder: String_Builder;
	append(*components_file_builder, generate_entity_component_serializers(*build_context));
	append(*components_file_builder, generate_entity_component_switches(*build_context));
	append(*components_file_builder, generate_archetype_component_switches(*build_context));

	write_entire_file(ZECS_COMPONENTS_GEN_PATH, builder_to_string(*components_file_builder));
	add_build_file(ZECS_COMPONENTS_GEN_PATH, w);
	print("Generated ZECS components file: %\n", ZECS_COMPONENTS_GEN_PATH);
}

generate_archetype_code :: (w: Workspace) {
	archetypes_file_builder: String_Builder;

	append(*archetypes_file_builder, generate_archetype_database(*build_context));
	append(*archetypes_file_builder, generate_archetype_index_lookup(*build_context));
	append(*archetypes_file_builder, generate_index_archetype_lookup(*build_context));
	append(*archetypes_file_builder, generate_component_storage_getter(*build_context));
	append(*archetypes_file_builder, generate_archetype_component_index_getters(*build_context));
	append(*archetypes_file_builder, generate_entity_component_initializers(*build_context));
	append(*archetypes_file_builder, generate_entity_initializer_dispatch(*build_context));
	append(*archetypes_file_builder, generate_archetype_initialization(*build_context));
	append(*archetypes_file_builder, generate_archetype_serializers(*build_context));

	write_entire_file(ZECS_ARCHETYPES_GEN_PATH, builder_to_string(*archetypes_file_builder));
	add_build_file(ZECS_ARCHETYPES_GEN_PATH, w);
	print("Generated ZECS archetypes file: %\n", ZECS_ARCHETYPES_GEN_PATH);
}

generate_query_code :: (w: Workspace) {
	query_file_builder: String_Builder;

	append(*query_file_builder, generate_queries(*build_context));

	write_entire_file(ZECS_QUERIES_GEN_PATH, builder_to_string(*query_file_builder));
	add_build_file(ZECS_QUERIES_GEN_PATH, w);
	print("Generated ZECS queries file: %\n", ZECS_QUERIES_GEN_PATH);
}

generate_observer_code :: (w: Workspace) {
	observer_file_builder: String_Builder;

	append(*observer_file_builder, generate_observers(*build_context));

	write_entire_file(ZECS_OBSERVERS_GEN_PATH, builder_to_string(*observer_file_builder));
	add_build_file(ZECS_OBSERVERS_GEN_PATH, w);
	print("Generated ZECS observers file: %\n", ZECS_OBSERVERS_GEN_PATH);
}


main :: () {}

#run build();

// #load meta files into the build program for gather_ and generate_ functions above
#load "src/ZAOSS/orders_meta.jai";
#load "src/ZAOSS/serialization_meta.jai";
#load "src/ZECS/ZECS_build_types.jai";
#load "src/ZECS/meta/ZECS_observers_meta.jai";
#load "src/ZECS/meta/ZECS_queries_meta.jai";
#load "src/ZECS/meta/ZECS_archetypes_meta.jai";
#load "src/ZECS/meta/ZECS_components_meta.jai";
#load "src/ZECS/meta/ZECS_constants_meta.jai";
#load "src/intel.jai";
