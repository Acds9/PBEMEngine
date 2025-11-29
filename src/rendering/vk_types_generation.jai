/*
* CURRENTLY UNUSED
* Not worth the maintenance and time investment with a solo project
*/

#import "Hash_Table";

GLSL_GEN_TARGET_FOLDER	:: "src/shaders/generated/common_types.glsl";

jai_glsl_notes : [3]string : .["glsl_struct_with_buffer", "glsl_buffer_struct", "glsl_push_constant"];

GLSL_Struct_Data :: struct {
	name	: string;
	notes	: [..]string;
	members : [..]Type_Info_Struct_Member;
}

GLSL_Structs :: struct {
	structs_with_buffers 	: [..]GLSL_Struct_Data;
	buffer_structs			: [..]GLSL_Struct_Data;
	push_constants			: [..]GLSL_Struct_Data;
}

get_glsl_type_name :: (type_inf: *Type_Info) -> string {
    if type_inf.type == {
        case .INTEGER;
            info := cast(*Type_Info_Integer) type_inf;
            if info.signed {
                if info.runtime_size == 1 return "int8_t";
                if info.runtime_size == 2 return "int16_t";
                if info.runtime_size == 4 return "int";
                if info.runtime_size == 8 return "int64_t";
            } else {
                if info.runtime_size == 1 return "uint8_t";
                if info.runtime_size == 2 return "uint16_t";
                if info.runtime_size == 4 return "uint";
                if info.runtime_size == 8 return "uint64_t";
            }
        case .FLOAT;
            if type_inf.runtime_size == 4 return "float";
            if type_inf.runtime_size == 8 return "double";
        case .BOOL;
            return "bool";
        case .STRUCT;
            info := cast(*Type_Info_Struct) type_inf;

            if info.name == "Vector3"        return "vec3";
            if info.name == "Vector4"        return "vec4";
            if info.name == "Matrix4"        return "mat4";
            if info.name == "VkDeviceAddress" return "uint64_t";

            return info.name;
		case .ARRAY;
			info := cast(*Type_Info_Array) type_inf;
			if info.array_type == .FIXED {
				element_name := get_glsl_type_name(info.element_type);
				return tprint("%[%]", element_name, info.array_count);
		}
    }
    return "/* unknown */";
}

has_code_note :: (notes: []*Code_Note, note: string) -> bool {
	for entry: notes {
		if entry.text == note {
			return true;
		}
	}
	return false;
}

find_glsl_noted_structs :: (typechecked: *Message_Typechecked, found_structs: *GLSL_Structs){    
    for decl: typechecked.declarations {
        code_decl := decl.expression;
  
        for note: code_decl.notes {
			if array_find(jai_glsl_notes, note.text) {
				if code_decl.expression && code_decl.expression.kind == .STRUCT {
					code_struct := cast(*Code_Struct) code_decl.expression;
					info := code_struct.defined_type;
                
					struct_data: GLSL_Struct_Data;
					struct_data.name = info.name;
					array_add(*struct_data.notes, note.text);
                
					for info.members {
						array_add(*struct_data.members, it);
					}

					if has_code_note(code_decl.notes, "glsl_struct_with_buffer") {
						array_add(*found_structs.structs_with_buffers, struct_data);
					}
					else if has_code_note(code_decl.notes, "glsl_buffer_struct") {
						array_add(*found_structs.buffer_structs, struct_data);
					}
					else if has_code_note(code_decl.notes, "glsl_push_constant") {
						array_add(*found_structs.push_constants, struct_data);
					}
					
					break;
				}
        	}
		}
	}
	
}

generate_glsl_structures :: (data: *GLSL_Structs) {
	builder: String_Builder;

	for entry: data.structs_with_buffers {
		print_to_builder(*builder, "struct % {\n", entry.name);
		for member: entry.members {
			print_to_builder(*builder, "\t% %; \n", get_glsl_type_name(member.type), member.name);
		}
		print_to_builder(*builder, "};\n");
		read_only := !array_find(entry.notes, "writeable");
		accessor := ifx read_only then " readonly" else "";
		print_to_builder(*builder, "layout(buffer_reference, scalar)% buffer %_Buffer {\n", accessor, entry.name);
		
			print_to_builder(*builder, "\t% %_data[]; \n", entry.name, to_lower_copy(entry.name));
		
		print_to_builder(*builder, "};\n");
	}

	write_entire_file(GLSL_GEN_TARGET_FOLDER, builder_to_string(*builder));
}
