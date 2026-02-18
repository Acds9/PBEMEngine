gather_order_executors :: (typechecked: *Message_Typechecked, headers: *[..]*Code_Procedure_Header) {
	for *typechecked.procedure_headers { // TODO: should we copy?
		array_add(headers, it.expression);
	}
}

generate_order_executors :: (proceedures: []*Code_Procedure_Header) -> string {
	builder: String_Builder;
	
	print_to_builder(*builder, "\n");
	print_to_builder(*builder, "// Order Executor Switch\n");
	print_to_builder(*builder, "execute_order :: (world: *ZWorld, order: *Order, order_data: []u8){\n");
	print_to_builder(*builder, "\tif !order || !world {\n");
		print_to_builder(*builder, "\t\tprint(\"Attempted to execute a null *Order or with a null ZWorld pointer\\n\");\n");
		print_to_builder(*builder, "\t\treturn;\n");
	print_to_builder(*builder, "\t}\n");
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
						print("ERROR: %'s first argument was not *ZWorld, this will not execute properly. Type was %. Order executor code generation aborted\n", proceedure.name, type_to_string(arg_type_info));
						return "";
					}
					array_add(*argument_strings, "world");
					continue arg; // ZWorld must always be the first argument, and we need to handle that one differently
				}
				if it_index == 1 {
					if type_to_string(arg_type_info) != "*Order" {
						print("ERROR: %'s second argument was not *Order, this will not execute properly. Type was %. Order executor code generation aborted\n", proceedure.name, type_to_string(arg_type_info));
						return "";
					}
					array_add(*argument_strings, "order");
					continue arg; // ZWorld must always be the first argument, and we need to handle that one differently
				}
				if it_index == 2 {
					if type_to_string(arg_type_info) != "[] u8" {
						print("ERROR: %'s third argument was not []u8, this will not execute properly. Type was %. Order executor code generation aborted\n", proceedure.name, type_to_string(arg_type_info));
						return "";
					}
					array_add(*argument_strings, "order_data");
					continue arg; // ZWorld must always be the first argument, and we need to handle that one differently
				}
				print_to_builder(*builder, "\t\t\targ_% : %;\n", it_index-3, type_to_string(arg_type_info));
				print_to_builder(*builder, "\t\t\toffset = order.data_offset;\n"); 
				print_to_builder(*builder, "\t\t\tdeserialize_from_buffer(*arg_%, order_data, *offset, size_of(%));\n", it_index-3, get_type(arg_type_info));
				array_add(*argument_strings, tprint("arg_%", it_index-3));
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
