
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

