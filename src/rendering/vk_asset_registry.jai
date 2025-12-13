Material_Definition :: struct {
	name			: string;
	type			: MATERIAL_TYPE;
	color_factors	: Vector4;
	albedo			: string;		// Relative path to /textures/ with no filetype
	albedo_sampler	: SAMPLER_TYPE;
}

Mesh_Definition :: struct {
	name				: string;
	mesh				: string;	// Relative path to /meshes/ with no filetype
	surface_materials 	: []string;
}

material_definitions :: Material_Definition.[
	.{
		name = "ion_frigate_hull",
		type = .OPAQUE,
		color_factors = .{1,1,1,1},
		albedo = "ion_frigate_hull_albedo",
		albedo_sampler = .NEAREST
	}
];

mesh_definitions :: Mesh_Definition.[
	.{
		name = "debug_sphere",
		mesh = "sphere_debug_1x1",
		surface_materials = .[]
	},
	.{
		name = "ion_frigate",
		mesh = "ion_frigate",
		surface_materials = string.["ion_frigate_hull"]
	}
];

load_material :: (zr: *ZRenderer, name: string) -> u32 {
	existing, found := table_find(*zr.material_instance_table, name);
    if found {
		return existing;
	}
	for material: material_definitions {
		if material.name != name {
			continue; // TODO: This isn't fast
		}

		albedo_image_path := sprint("H:/PBEMJai/content/textures/%.ktx2", material.albedo);
		defer free(albedo_image_path);

		albedo_image := load_image(zr, albedo_image_path);

		material_instance : Material_Instance;
		material_instance.type = material.type;
		material_instance.color_factors = material.color_factors;
		material_instance.albedo_image_index = albedo_image.image_index;
		material_instance.albedo_sampler = material.albedo_sampler;

		material_index : u32;
		if material_instance.type == {
			case .OPAQUE; {
				material_index = zr.m_opaque.create_material_instance(*zr.m_opaque, zr, *material_instance); 
				table_add(*zr.material_instance_table, material.name, material_index);
				return material_index; 
			};
			// Add more here later
		}
	}
	return U32_MAX;
}

load_meshes :: (zr: *ZRenderer) {
	for mesh: mesh_definitions {
		existing, found := table_find(*zr.mesh_map, mesh.name);
		if found {
			continue;
		}
		mesh_path := sprint("H:/PBEMJai/content/meshes/%.glb", mesh.mesh);
		defer free(mesh_path);

		loaded_mesh := load_glt_mesh(zr, mesh_path);
		loaded_mesh.name = mesh.name;
		for material: mesh.surface_materials {
			idx := load_material(zr, material);
			if idx == U32_MAX {
				panic(sprint("Could not find material to load. Mesh: %, Material: %", loaded_mesh.name, material));
			}
			surface : *Geo_Surface = get_mesh_geo_surface(zr, loaded_mesh, xx,no_check it_index);
			surface.default_material_instance = idx;
		}
		table_add(*zr.mesh_map, loaded_mesh.name, loaded_mesh);
	}
}