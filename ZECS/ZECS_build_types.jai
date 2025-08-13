
Archetype_Build_Metadata :: struct {
    name                : string;
    entity_components   : [..]string;
    arch_components     : [..]string;
	a_c_defaults		: [..]Archetype_Component_Default;
    tags                : u64;  
    chunk_size          : u32 = 32;
}

Archetype_Component_Default :: struct {
	comp_type_name		: string;
	data_type			: *Type_Info;
	data_ptr			: *u8;
	data_size			: u32;
}

Query_Build_Metadata :: struct {
	name					: string;
    entity_components		: [..]string;
    archetype_components	: [..]string;
    tags					: u64; 
    options					: u32; // Should be called flags and be u8
}


Observer_Build_Metadata :: struct {
	name					: string;
    entity_components		: [..]string;
    archetype_components	: [..]string;
    tags					: u64;
    flags					: u8;
	priority				: u8;
}

gather_component_types :: (typechecked: *Message_Typechecked) -> entity_comps: [..]string, arch_comps: [..]string, tags: [..]string {
	entity_comps 	: [..]string;
	arch_comps 		: [..]string;
	tags 			: [..]string;
	x := typechecked.declarations;
    for typechecked.structs{
		info := it.expression.defined_type;
        
        if is_subclass_of(info, "Entity_Component") {
            array_add(*entity_comps, info.name);
        } else if is_subclass_of(info, "Archetype_Component") {
            array_add(*arch_comps, info.name);
        } else if is_subclass_of(info, "Tag") {
            array_add(*tags, info.name);
        }
    }
	return entity_comps, arch_comps, tags;
}

gather_archetypes :: (typechecked: *Message_Typechecked) -> [..]Archetype_Build_Metadata {
	archetypes : [..]Archetype_Build_Metadata;
	
	for typechecked.structs {
        info := it.expression.defined_type;
        
        if is_subclass_of(info, "Archetype") && info.name != "Archetype" {
			archetype : Archetype_Build_Metadata;
			archetype.name = info.name;

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
								type := <<type_ptr;
								array_add(*archetype.entity_components, type.name);
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
								type := <<type_ptr;
								array_add(*archetype.arch_components, type.name);
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
			array_add(*archetypes, archetype);
        }
    }
	return archetypes;
}

gather_queries :: (typechecked: *Message_Typechecked) -> [..]Query_Build_Metadata {
	queries: [..]Query_Build_Metadata;

	for typechecked.structs {
		info := it.expression.defined_type;
        
        if is_subclass_of(info, "Query") && info.name != "Query" {
			query: Query_Build_Metadata;
			query.name = info.name;
			
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
								type := <<type_ptr;
								array_add(*query.entity_components, type.name);
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
								type := <<type_ptr;
								array_add(*query.archetype_components, type.name);
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
						flags_value := <<cast(*u8)any.value_pointer;
						query.options = flags_value;
					}
				}
			}
			array_add(*queries, query);
		}
	}
	return queries;
}


gather_observers :: (typechecked: *Message_Typechecked) -> [..]Observer_Build_Metadata {
	observers: [..]Observer_Build_Metadata;

	for typechecked.structs {
		info := it.expression.defined_type;
        
        if is_subclass_of(info, "Observer") && info.name != "Observer" {
			observer: Observer_Build_Metadata;
			observer.name = info.name;
			
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
								type := <<type_ptr;
								array_add(*observer.entity_components, type.name);
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
								type := <<type_ptr;
								array_add(*observer.archetype_components, type.name);
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
						flags_value := <<cast(*u8)any.value_pointer;
						observer.flags = flags_value;
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
					// How the fuck do we extract #code?
					// Ok so first off it's of type Code, see code_type.jai
					// See compiler.jai line 359, the code might not be in STRUCTS array
					// It's likely a Code_Node of either type BODY or type CODE_DIRECTIVE
					// Can be cast to Code_Directive_Code if so, which containts a *Code_Node, which likely points to the actual code, which is probably BODY?
					// Can we get Code_Struct out of Code_Block?
					// But that just brings us back to a bunch of Code_Blocks, so maybe not
					// For the sake of mental sanity we skip this for now and use #insert
					/*else if (member.name == "BODY") {	
						print("Warning: Found BODY\n");
						node := cast(*Code_Block)member.type;
						print("Warning: %\n", <<node);
					}*/
				}
			}
			array_add(*observers, observer);
		}
	}
	return observers;
}