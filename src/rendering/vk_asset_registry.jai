/*Asset_Registry :: struct {
	mesh_files	: Table(string, string);
	image_files	: Table(string, string);

	build_mesh_file_registry :: (using self: *Asset_Registry) {
		table_add(*mesh_files, "ion_frigate", "H:/PBEMJai/content/meshes/ion_frigate.glb");
	}
	build_image_file_registry :: (using self: *Asset_Registry) {
		table_add(*image_files, "ion_frigate_hull_albedo", "H:/PBEMJai/content/textures/ion_frigate_hull_albedo.ktx2");
	}
}

ASSET_REGISTRY : Asset_Registry;

Definition_Registry :: struct {

	Material_Definition :: struct {
		type 		: Material_Type;
		constants 	: Material_Constants;
	}
	Mesh_Asset :: struct {
		mesh_name		 	: string;
		primitive_materials : [..]string; // index 0 = first primitive and so on
	}

	material_instance_definitions 	: Table(string, Material_Definition);
	mesh_definitions				: Table(string, Mesh_Asset);

	build_material_instance_definitions :: (using self: *Definition_Registry) {
		type		: Material_Type;
		constants 	: Material_Constants;

		type = .OPAQUE;
		constants.opaque.albedo_image_index = image.image_index;
		constants.opaque.albedo_sampler_index = zr.sampler_nearest_index;
		//ion_frigate_hull_mat : Material_Definition = ;
		table_add(*material_instance_definitions, "ion_frigate_hull", .{type, constants});
	}
}

DEFINITION_REGISTRY : Definition_Registry;

build_mesh_asset_registry :: () {
	success : bool;
	image 	: *Allocated_Image;
	
	constants 			: Material_Constants;
	primitive_materials : [..]Material_Asset;
	asset 				: Mesh_Asset;

	table_find(*ASSET_REGISTRY.image, "ion_frigate_hull_albedo");
	constants.
	table_add(*MESH_ASSET_REGISTRY, "ion_frigate", "H:/PBEMJai/content/meshes/ion_frigate.glb");
}
*/
load_assets :: (zr: *ZRenderer) {

	//Ion Frigate
	{
		ion_frigate_mesh := load_glt_meshes(zr, "H:/PBEMJai/content/meshes/ion_frigate.glb");
		ion_frigate_mesh.name = "ion_frigate";
		table_add(*zr.mesh_map, ion_frigate_mesh.name, ion_frigate_mesh);

		image := load_image(*ZRENDERER, "H:/PBEMJai/content/textures/ion_frigate_hull_albedo.ktx2");
		material_instance : Material_Instance;
		material_instance.color_factors = Vector4.{1,1,1,1};
		material_instance.albedo_image_index = image.image_index;
		material_instance.albedo_sampler_index = zr.sampler_nearest_index;
		ion_frigate_hull_material := zr.m_opaque.create_material_instance(*zr.m_opaque, zr, *material_instance);
		ion_frigate_mesh.surfaces[0].material_instance = <<table_add(*zr.material_instance_table, "ion_frigate_hull_material", ion_frigate_hull_material);
	}

	//Debug sphere
	{
		debug_sphere_mesh := load_glt_meshes(zr, "H:/PBEMJai/content/meshes/sphere_debug_1x1.glb");
		debug_sphere_mesh.name = "debug_sphere";
		table_add(*zr.mesh_map, debug_sphere_mesh.name, debug_sphere_mesh);
	}
}