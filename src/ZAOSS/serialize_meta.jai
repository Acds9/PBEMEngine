has_code_note :: (notes: []*Code_Note, note: string) -> bool {
	for entry: notes {
		if entry.text == note {
			return true;
		}
	}
	return false;
}

gather_structs_to_serialize :: (typechecked: *Message_Typechecked, infos: *[..]*Type_Info_Struct) {
	for typechecked.declarations {
		decl := it.expression;
		if !has_code_note(decl.notes, "serialize") continue;
    
		if decl.expression && decl.expression.kind == .STRUCT {
			code_struct := cast(*Code_Struct) decl.expression;
			info: *Type_Info_Struct = xx,no_check code_struct.defined_type;
			array_add(infos, info);
		}
	}
}

generate_struct_serializers :: (infos: []*Type_Info_Struct) -> string {
	builder: String_Builder;

	print_to_builder(*builder, "// Struct Serializers\n");
	for type: infos {
		print_to_builder(*builder, "serialize :: (dest: *[..]u8, src: *%){\n", type.name);
		for *member: type.members {
			if array_find(member.notes, "no_serialize") {
				continue member;
			}
			if member.type.type == .ARRAY {
				generate_array_serialize(*builder, tprint("src.%", member.name), cast(*Type_Info_Array)member.type, 0);
				continue member;
			}
			if member.type.type == .STRUCT {
				member_type_struct := cast(*Type_Info_Struct)member.type;
				// Recursively call this function to serialize the struct member
				print_to_builder(*builder, "\tserialize(dest, *src.%);\n", member.name); 
				continue member;
			}
			if member.type.type == .STRING {
				print_to_builder(*builder, "\tserialize_to_buffer_string(dest, src.%);\n", member.name);
				continue member;
			}
			// Not a struct or an array, so we just serialize like usual
			print_to_builder(*builder, "\tserialize_to_buffer(dest, *src.%);\n", member.name);
		}
			//member_type := get_type(arg_type_info);
		print_to_builder(*builder, "}\n");
	}
	return builder_to_string(*builder);
}

generate_array_serialize :: (builder: *String_Builder, access: string, info: *Type_Info_Array, depth: s32) {
   	tab_string : string;
	for 0..depth {
		tab_string = tprint("% %", tab_string, "\t");
	}
	// For non-fixed arrays
    if info.array_type != .FIXED {
        print_to_builder(builder, "%serialize_to_buffer(dest, *%.count);\n", tab_string, access);
    }
    
    element := info.element_type;
    iter := tprint("it_%", depth);
    
    if element.type == .ARRAY {
		print_to_builder(builder, "%for *%: % {\n", tab_string, iter, access);
			generate_array_serialize(builder, tprint("%.*", iter), cast(*Type_Info_Array)element, depth + 1);
		print_to_builder(builder, "%}\n", tab_string);
	} else if element.type == .STRUCT {
		print_to_builder(builder, "%for *%: % {\n", tab_string, iter, access);
			print_to_builder(builder, "% \tserialize(dest, %);\n", tab_string, iter);
		print_to_builder(builder, "%}\n", tab_string);
	} else {
        // Leaf simple type, bulk copy
        if info.array_type == .FIXED {
            print_to_builder(builder, "%serialize_to_buffer(dest, %.data, %*%);\n", tab_string, access, info.array_count, element.runtime_size);
		} else if element.type == .STRING {
			print_to_builder(builder, "%for str: % {\n", tab_string, access);
				print_to_builder(builder, "% \tserialize_to_buffer_string(dest, str);\n", tab_string);
			print_to_builder(builder, "%}\n", tab_string);
        } else {
            print_to_builder(builder, "%serialize_to_buffer(dest, %.data, %.count * %);\n", tab_string, access, access, element.runtime_size);
        }
    }
}

generate_struct_deserializers :: (infos: []*Type_Info_Struct) -> string {
    builder: String_Builder;
    print_to_builder(*builder, "// Struct Deserializers\n");
    for type: infos {
        print_to_builder(*builder, "deserialize :: (dest: *%, src: []u8, offset: *s64){\n", type.name);
        for *member: type.members {
            if array_find(member.notes, "no_serialize") {
                continue member;
            }
            if member.type.type == .ARRAY {
                generate_array_deserialize(*builder, tprint("dest.%", member.name), cast(*Type_Info_Array)member.type, 0);
                continue member;
            }
            if member.type.type == .STRUCT {
                print_to_builder(*builder, "\tdeserialize(*dest.%, src, offset);\n", member.name);
                continue member;
            }
            if member.type.type == .STRING {
                print_to_builder(*builder, "\tdest.% = deserialize_from_buffer_string(src, offset);\n", member.name);
                continue member;
            }
            print_to_builder(*builder, "\tdeserialize_from_buffer(*dest.%, src, offset);\n", member.name);
        }
        print_to_builder(*builder, "}\n");
    }
    return builder_to_string(*builder);
}

generate_array_deserialize :: (builder: *String_Builder, access: string, info: *Type_Info_Array, depth: s32) {
    tab_string: string;
    for 0..depth {
        tab_string = tprint("% %", tab_string, "\t");
    }

    element := info.element_type;
    iter := tprint("it_%", depth);

    // Read count and allocate for non-fixed arrays
    if info.array_type != .FIXED {
        if info.array_type == .RESIZABLE {
            // Read count into a temp variable, NOT directly into .count as array_resize early-returns when old_count == new_count
            // So writing to .count first would skip allocation entirely, .count will be correct but .data won't be
			print_to_builder(builder, "%{\n", tab_string);
			print_to_builder(builder, "%\tcount: s64;\n", tab_string);
			print_to_builder(builder, "%\tdeserialize_from_buffer(*count, src, offset);\n", tab_string);
            print_to_builder(builder, "%\tarray_resize(*%, count);\n", tab_string, access);
			//print_to_builder(builder, "%\tprint(\"Found Orders: \%\\n\", count);\n", tab_string);
			print_to_builder(builder, "%}\n", tab_string);
        } else {
            // Slice
            print_to_builder(builder, "%deserialize_from_buffer(*%.count, src, offset);\n", tab_string, access);
            print_to_builder(builder, "% %.data = alloc(%.count * %);\n", tab_string, access, access, element.runtime_size);
        }
    }

    if element.type == .ARRAY {
        print_to_builder(builder, "%for *%: % {\n", tab_string, iter, access);
            generate_array_deserialize(builder, tprint("%.*", iter), cast(*Type_Info_Array)element, depth + 1);
        print_to_builder(builder, "%}\n", tab_string);
    } else if element.type == .STRUCT {
        print_to_builder(builder, "%for *%: % {\n", tab_string, iter, access);
            print_to_builder(builder, "% \tdeserialize(%, src, offset);\n", tab_string, iter);
        print_to_builder(builder, "%}\n", tab_string);
    } else if element.type == .STRING {
        print_to_builder(builder, "%for *%: % {\n", tab_string, iter, access);
            print_to_builder(builder, "% \t%.* = deserialize_from_buffer_string(src, offset);\n", tab_string, iter);
        print_to_builder(builder, "%}\n", tab_string);
    } else {
        // Leaf simple type — bulk copy
        if info.array_type == .FIXED {
            print_to_builder(builder, "%deserialize_from_buffer(%.data, src, offset, %*%);\n", tab_string, access, info.array_count, element.runtime_size);
        } else {
            print_to_builder(builder, "%deserialize_from_buffer(%.data, src, offset, %.count * %);\n", tab_string, access, access, element.runtime_size);
        }
    }
}