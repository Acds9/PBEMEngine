gather_order_executors :: (typechecked: *Message_Typechecked, headers: *[..]*Code_Procedure_Header) {
	for *typechecked.procedure_headers { // TODO: should we copy?
		array_add(headers, it.expression);
	}
}

generate_order_executors :: (proceedures: []*Code_Procedure_Header) -> string {
	builder: String_Builder;
	
	print_to_builder(*builder, "\n");
	print_to_builder(*builder, "// Order Executor Switch\n");
	print_to_builder(*builder, "execute_order :: (order: *Order, world: *ZWorld){\n");
	print_to_builder(*builder, "\toffset : s64;\n");
	print_to_builder(*builder, "\tif order.type == {\n");

	#load "zaoss_types.jai";
	handled_types : [..]string;
	enum_info := type_info(ORDER_TYPE);
	for type: enum_info.names {
		print_to_builder(*builder, "\t\tcase .%; {\n", type);
		for proceedure: proceedures {
			found, type_string := contains(proceedure.name, "order_executor_");
			if !found {
				continue proceedure;
			}
			
			upper_type := to_upper_copy(type_string);
			if upper_type != type {
				continue proceedure;
			}
			
			argument_strings : [..]string;
			for arg: proceedure.arguments {
				type_inst : *Code_Type_Instantiation = arg.type_inst;
				arg_type_info : *Type_Info = type_inst.result;
				if it_index == 0 {
					if type_to_string(arg_type_info) != "*ZWorld" {
						print("ERROR: %'s first argument was not *ZWorld, this will not execute properly. Order executor code generation aborted\n", proceedure.name);
						return "";
					}
					array_add(*argument_strings, "world");
					continue arg; // ZWorld must always be the first argument, and we need to handle that one differently
				}
				print_to_builder(*builder, "\t\t\targ_% : %;\n", it_index, type_to_string(arg_type_info));
				print_to_builder(*builder, "\t\t\tdeserialize_from_buffer(*arg_%, order.data, *offset);\n", it_index);
				array_add(*argument_strings, tprint("arg_%", it_index));

				
			}
			final_args := join(..argument_strings, ", ", false, false);
			
			print_to_builder(*builder, "\t\t\t%(%);\n", proceedure.name, final_args);
			print_to_builder(*builder, "\t\t\treturn;\n");
			array_add(*handled_types, type);
		}
		print_to_builder(*builder, "\t\t}\n");
	}
	print_to_builder(*builder, "\t}\n");
	print_to_builder(*builder, "\tprint(\"WARNING: An order execution was called but no matching case was found\\n\");\n");	
	print_to_builder(*builder, "}\n");
	
	for enum_name: enum_info.names {
		found : bool;
		for handled_name: handled_types {
			if handled_name == enum_name {
				found = true;
				break handled_name;
			}
		}
		if !found {
			print("WARNING: No order executor procedure found for %, order will no-op\n", enum_name);
		}
	}

	return builder_to_string(*builder);
}
