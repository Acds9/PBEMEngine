#import "Compiler";
#import "String";
#import "Sort";

BUILD_WORLD_TYPE_MENU 		:: 1;
BUILD_WORLD_TYPE_REPLAY 	:: 2;
BUILD_WORLD_TYPE_SIMULATION :: 4;

compare_build_metadata :: (a: Query_Build_Metadata, b: Query_Build_Metadata) -> s64 {
	return compare_strings(a.type_data.name, b.type_data.name);
}

compare_build_metadata :: (a: Observer_Build_Metadata, b: Observer_Build_Metadata) -> s64 {
	return compare_strings(a.type_data.name, b.type_data.name);
}

Build_Context :: struct {
	entity_components    	: [..]*Type_Info_Struct;	// Sorted by name, index IS the bit index
	archetype_components 	: [..]*Type_Info_Struct;	// Sorted by name
	tags					: [..]*Type_Info_Struct;	// Sorted by name	

	archetypes				: [..]Archetype_Build_Metadata; // Sorted by name

	queries					: [..]Query_Build_Metadata; // Sorted by name

	observers				: [..]Observer_Build_Metadata; // Sorted by name
}

Archetype_Build_Metadata :: struct {
    type_data			: *Type_Info_Struct;
    entity_components   : [..]*Type_Info_Struct;
    archetype_components: [..]*Type_Info_Struct;
	a_c_defaults		: [..]Archetype_Component_Default;
    tags                : u64;
    chunk_size          : u32 = 32;
}

lookup_ec_bit_index :: (build_context: *Build_Context, comp: *Type_Info_Struct) -> u32 {
	for build_context.entity_components {
		if it.name == comp.name return cast(u32) it_index;
	}
	assert(false, tprint("Entity component '%' not found in build_context", comp.name));
	return 0;
}

lookup_ac_bit_index :: (build_context: *Build_Context, comp: *Type_Info_Struct) -> u32 {
	for build_context.archetype_components {
		if it.name == comp.name return cast(u32) it_index;
	}
	assert(false, tprint("Archetype component '%' not found in build_context", comp.name));
	return 0;
}

// Computes a bitmask as [..]u64, matching the layout of Bit_Field(N).data
compute_bitmask :: (total_bits: s64, set_bits: [..]u32) -> [..]u64 {
	num_words := cast(s64) ((total_bits + 63) / 64);
	if num_words < 1 num_words = 1;
	mask: [..]u64;
	array_resize(*mask, num_words);
	for set_bits {
		word   := it / 64;
		offset := it % 64;
		mask[word] |= (cast(u64)1 << offset);
	}
	return mask;
}


compare_type_info_structs :: (a_info: *Type_Info_Struct, b_info: *Type_Info_Struct) -> s64 {
	a, b := a_info.name, b_info.name;
	for 0..a.count-1 {
		if it >= b.count return 1;
		delta := cast(s64) a[it] - cast(s64) b[it];
		if delta return delta;
	}
	if b.count > a.count return -1;
	return 0;
}

compare_build_metadata :: (a: Archetype_Build_Metadata, b: Archetype_Build_Metadata) -> s64 {
	return compare_strings(a.type_data.name, b.type_data.name);
}

Archetype_Component_Default :: struct {
	comp_type_name		: string;
	data_type			: *Type_Info;
	data_ptr			: *u8;
	data_size			: u32;
}

Query_Build_Metadata :: struct {
	type_data				: *Type_Info_Struct;
    entity_components		: [..]*Type_Info_Struct;
    archetype_components	: [..]*Type_Info_Struct;
    tags					: u64; 
    options					: u32; // Should be called flags and be u8
	world_types				: u8;
	counter_index			: u32; // For ATOMIC_COUNTER query option
}

Observer_Build_Metadata :: struct {
	type_data				: *Type_Info_Struct;
    entity_components		: [..]*Type_Info_Struct;
    archetype_components	: [..]*Type_Info_Struct;
    tags					: u64;
    flags					: u32;
	world_types				: u8;
	priority				: u8;
}

gather_component_types :: (typechecked: *Message_Typechecked, build_context: *Build_Context) -> bool {
	x := typechecked.declarations;
    for typechecked.structs{
		info : *Type_Info_Struct = xx,no_check it.expression.defined_type;

        if is_subclass_of(info, "Entity_Component") {
            array_add(*build_context.entity_components, info);
        } else if is_subclass_of(info, "Archetype_Component") {
            array_add(*build_context.archetype_components, info);
        } else if is_subclass_of(info, "Tag") {
            array_add(*build_context.tags, info);
        }
    }

	quick_sort(build_context.entity_components, compare_type_info_structs);
	quick_sort(build_context.archetype_components, compare_type_info_structs);
	quick_sort(build_context.tags, compare_type_info_structs);

	return build_context.entity_components.count || build_context.archetype_components.count || build_context.tags.count;
}

gather_archetypes :: (typechecked: *Message_Typechecked, build_context: *Build_Context) {
	for typechecked.structs {
        info := it.expression.defined_type;
      
        if is_subclass_of(info, "Archetype") && info.name != "Archetype" {
			archetype : Archetype_Build_Metadata;
			archetype.type_data = info;
			
			for member: info.members {
				if(member.flags & .CONSTANT) {
					if(member.name == "ENTITY_COMPONENTS") {
						// We know it's an array
						array_type := cast(*Type_Info_Array)member.type;
						count := array_type.array_count;
						
						any: Any;
						any.type = member.type;

						if(member.offset_into_constant_storage >= 0) {
							any.value_pointer = info.constant_storage.data + member.offset_into_constant_storage;
						}
						else {
							any.value_pointer = info.constant_storage.data + member.offset_in_bytes;
						}

						// we know array type is fixed
						data := any.value_pointer; // So the data is right here
						for i: 0..count-1 {
							pointer := data + array_type.element_type.runtime_size * i;

							item: Any;
							item_type:= array_type.element_type;
							item.value_pointer = pointer;

							// Extract
							type_ptr := (.*) cast(**Type_Info_Struct) item.value_pointer;
							if type_ptr {
								array_add(*archetype.entity_components, type_ptr);
							}
						}
					}
					else if (member.name == "ARCHETYPE_COMPONENTS") {
						array_type := cast(*Type_Info_Array)member.type;
						count := array_type.array_count;
						
						any: Any;
						any.type = member.type;

						if(member.offset_into_constant_storage >= 0) {
							any.value_pointer = info.constant_storage.data + member.offset_into_constant_storage;
						}
						else {
							any.value_pointer = info.constant_storage.data + member.offset_in_bytes;
						}

						// we know array type is fixed
						data := any.value_pointer; // So the data is right here
						for i: 0..count-1 {
							pointer := data + array_type.element_type.runtime_size * i;

							item: Any;
							item_type:= array_type.element_type;
							item.value_pointer = pointer;

							// Extract
							type_ptr := (.*) cast(**Type_Info_Struct) item.value_pointer;
							if type_ptr {
								array_add(*archetype.archetype_components, type_ptr);
							}
						}
					}
					else if (member.name == "TAGS") {
						any: Any;
						any.type = member.type;
    
						if(member.offset_into_constant_storage >= 0) {
							any.value_pointer = info.constant_storage.data + member.offset_into_constant_storage;
						} else {
							continue; // No valid offset
						}
    
						// The "array" is just the raw bytes of the u64 enum value
						tags_value := <<cast(*u64)any.value_pointer;
						archetype.tags = tags_value;
					}
					else if (starts_with(member.name, "DEFAULT_")) {
						_,_,comp_name := split_from_left(member.name, "_");  // Skip "DEFAULT_"

						default_value: Archetype_Component_Default;
						default_value.comp_type_name = comp_name;
						default_value.data_type = member.type;
						default_value.data_ptr = info.constant_storage.data + member.offset_into_constant_storage;
						default_value.data_size = cast(u32)member.type.runtime_size;

						array_add(*archetype.a_c_defaults, default_value);
					}
					else if (member.name == "CHUNK_SIZE") {
						chunk_value := <<cast(*u32)(info.constant_storage.data + member.offset_into_constant_storage);

						archetype.chunk_size = chunk_value;
					}
				}
			}
			array_add(*build_context.archetypes, archetype);
        }
    }
}

gather_queries :: (typechecked: *Message_Typechecked, build_context: *Build_Context) {
	for typechecked.structs {
		info := it.expression.defined_type;
        
        if is_subclass_of(info, "Query") && info.name != "Query" {
			query: Query_Build_Metadata;
			query.type_data = info;
			
			for member: info.members {
				if(member.flags & .CONSTANT) {
					if(member.name == "ENTITY_COMPONENTS") {
						// We know it's an array
						array_type := cast(*Type_Info_Array)member.type;
						count := array_type.array_count;
						
						any: Any;
						any.type = member.type;

						if(member.offset_into_constant_storage >= 0) {
							any.value_pointer = info.constant_storage.data + member.offset_into_constant_storage;
						}
						else {
							any.value_pointer = info.constant_storage.data + member.offset_in_bytes;
						}

						// we know array type is fixed
						data := any.value_pointer; // So the data is right here
						for i: 0..count-1 {
							pointer := data + array_type.element_type.runtime_size * i;

							item: Any;
							item_type:= array_type.element_type;
							item.value_pointer = pointer;

							// Extract
							type_ptr := (.*) cast(**Type_Info_Struct) item.value_pointer;
							if type_ptr {
								array_add(*query.entity_components, type_ptr);
							}
						}
					}
					else if (member.name == "ARCHETYPE_COMPONENTS") {
						array_type := cast(*Type_Info_Array)member.type;
						count := array_type.array_count;
						
						any: Any;
						any.type = member.type;

						if(member.offset_into_constant_storage >= 0) {
							any.value_pointer = info.constant_storage.data + member.offset_into_constant_storage;
						}
						else {
							any.value_pointer = info.constant_storage.data + member.offset_in_bytes;
						}

						// we know array type is fixed
						data := any.value_pointer; // So the data is right here
						for i: 0..count-1 {
							pointer := data + array_type.element_type.runtime_size * i;

							item: Any;
							item_type:= array_type.element_type;
							item.value_pointer = pointer;

							// Extract
							type_ptr := (.*) cast(**Type_Info_Struct) item.value_pointer;
							if type_ptr {
								array_add(*query.archetype_components, type_ptr);
							}
						}
					}
					else if (member.name == "TAGS") {
						any: Any;
						any.type = member.type;
    
						if(member.offset_into_constant_storage >= 0) {
							any.value_pointer = info.constant_storage.data + member.offset_into_constant_storage;
						} else {
							continue; // No valid offset
						}
    
						// The "array" is just the raw bytes of the u64 enum value
						tags_value := <<cast(*u8)any.value_pointer;
						query.tags = tags_value;
					}
					else if (member.name == "QUERY_FLAGS") {
						any: Any;
						any.type = member.type;
    
						if(member.offset_into_constant_storage >= 0) {
							any.value_pointer = info.constant_storage.data + member.offset_into_constant_storage;
						} else {
							continue; // No valid offset
						}
    
						// The "array" is just the raw bytes of the u64 enum value
						flags_value := <<cast(*u32)any.value_pointer;
						query.options = flags_value;
					}
					else if (member.name == "WORLD_TYPES") {
						any: Any;
						any.type = member.type;
    
						if(member.offset_into_constant_storage >= 0) {
							any.value_pointer = info.constant_storage.data + member.offset_into_constant_storage;
						} else {
							continue; // No valid offset
						}
    
						// The "array" is just the raw bytes of the u64 enum value
						type_value := <<cast(*u8)any.value_pointer;
						query.world_types = type_value;
					}
				}
			}
			array_add(*build_context.queries, query);
		}
	}
}

gather_observers :: (typechecked: *Message_Typechecked, ctx: *Build_Context) {
	for typechecked.structs {
		info := it.expression.defined_type;
        
        if is_subclass_of(info, "Observer") && info.name != "Observer" {
			observer: Observer_Build_Metadata;
			observer.type_data = info;
			
			for member: info.members {
				if(member.flags & .CONSTANT) {
					if(member.name == "ENTITY_COMPONENTS") {
						// We know it's an array
						array_type := cast(*Type_Info_Array)member.type;
						count := array_type.array_count;
						
						any: Any;
						any.type = member.type;

						if(member.offset_into_constant_storage >= 0) {
							any.value_pointer = info.constant_storage.data + member.offset_into_constant_storage;
						}
						else {
							any.value_pointer = info.constant_storage.data + member.offset_in_bytes;
						}

						// we know array type is fixed
						data := any.value_pointer; // So the data is right here
						for i: 0..count-1 {
							pointer := data + array_type.element_type.runtime_size * i;

							item: Any;
							item_type:= array_type.element_type;
							item.value_pointer = pointer;

							// Extract
							type_ptr := (.*) cast(**Type_Info_Struct) item.value_pointer;
							if type_ptr {
								array_add(*observer.entity_components, type_ptr);
							}
						}
					}
					else if (member.name == "ARCHETYPE_COMPONENTS") {
						array_type := cast(*Type_Info_Array)member.type;
						count := array_type.array_count;
						
						any: Any;
						any.type = member.type;

						if(member.offset_into_constant_storage >= 0) {
							any.value_pointer = info.constant_storage.data + member.offset_into_constant_storage;
						}
						else {
							any.value_pointer = info.constant_storage.data + member.offset_in_bytes;
						}

						// we know array type is fixed
						data := any.value_pointer; // So the data is right here
						for i: 0..count-1 {
							pointer := data + array_type.element_type.runtime_size * i;

							item: Any;
							item_type:= array_type.element_type;
							item.value_pointer = pointer;

							// Extract
							type_ptr := (.*) cast(**Type_Info_Struct) item.value_pointer;
							if type_ptr {
								array_add(*observer.archetype_components, type_ptr);
							}
						}
					}
					else if (member.name == "TAGS") {
						any: Any;
						any.type = member.type;
    
						if(member.offset_into_constant_storage >= 0) {
							any.value_pointer = info.constant_storage.data + member.offset_into_constant_storage;
						} else {
							continue; // No valid offset
						}
    
						// The "array" is just the raw bytes of the u64 enum value
						tags_value := <<cast(*u8)any.value_pointer;
						observer.tags = tags_value;
					}
					else if (member.name == "FLAGS") {
						any: Any;
						any.type = member.type;
    
						if(member.offset_into_constant_storage >= 0) {
							any.value_pointer = info.constant_storage.data + member.offset_into_constant_storage;
						} else {
							continue; // No valid offset
						}
    
						// The "array" is just the raw bytes of the u64 enum value
						flags_value := <<cast(*u32)any.value_pointer;
						observer.flags = flags_value;
					}
					else if (member.name == "WORLD_TYPES") {
						any: Any;
						any.type = member.type;
    
						if(member.offset_into_constant_storage >= 0) {
							any.value_pointer = info.constant_storage.data + member.offset_into_constant_storage;
						} else {
							continue; // No valid offset
						}
    
						// The "array" is just the raw bytes of the u64 enum value
						types_value := <<cast(*u8)any.value_pointer;
						observer.world_types = types_value;
					}
					else if (member.name == "PRIORITY") {
						any: Any;
						any.type = member.type;
    
						if(member.offset_into_constant_storage >= 0) {
							any.value_pointer = info.constant_storage.data + member.offset_into_constant_storage;
						} else {
							continue; // No valid offset
						}
    
						// The "array" is just the raw bytes of the u64 enum value
						flags_value := <<cast(*u8)any.value_pointer;
						observer.priority = flags_value;
					} 
				}
			}
			array_add(*ctx.observers, observer);
		}
	}
}