#import "Basic";
#import "File";
#import "File_Utilities";
#import "Math";
ht :: #import "Hash_Table";

// Contains a linear database of all mesh assets on disk
Mesh_Asset :: struct {
	name		: string;
	asset_path	: string;
}

mesh_asset_database : ht.Table(string, Mesh_Asset, null, LOAD_FACTOR_PERCENT=70); // database of mesh assets ON DISK, not loaded

init_mesh_asset_database :: (asset_folder: string) { // TODO: need a better way to get asset names out, maybe do it manually?
	mesh_files := file_list_ext(asset_folder, ".obj", true);
	for mesh_files {
		slash_found, left, right := split_from_right(it, "/");
		if !slash_found continue;
		dot_found, name, ext := split_from_right(right, ".");
		if !dot_found continue;
		ht.table_add(*mesh_asset_database, name, .{name, it});
	}
}

Mesh_Entry :: struct {
	asset_name	: string;
	//model		: rl.Model;
}



Mesh_Instance :: struct {
	Mesh_ID		: u32;
	Transform	: Matrix4;
//	model_ptr	: *rl.Model;
}

// Maps an entity's u64 to a mesh proxy instance
Mesh_Instance_Table :: ht.Table(u64, Mesh_Instance, null, LOAD_FACTOR_PERCENT=70);