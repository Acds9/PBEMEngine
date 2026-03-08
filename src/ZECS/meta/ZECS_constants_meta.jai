generate_ZECS_constants :: (build_context: *Build_Context) -> string {
	builder: String_Builder;

	print_to_builder(*builder, "// ZECS Constants\n");
	print_to_builder(*builder, "MAX_ENTITY_COMPONENTS :: %;\n", build_context.entity_components.count);
	print_to_builder(*builder, "MAX_ARCH_COMPONENTS :: %;\n", build_context.archetype_components.count);
	print_to_builder(*builder, "MAX_TAGS :: %;\n", build_context.tags.count);
	print_to_builder(*builder, "MAX_ARCHETYPES :: %;\n", 128); // TODO: need to generate this
	print_to_builder(*builder, "\n");

	return builder_to_string(*builder);	
}