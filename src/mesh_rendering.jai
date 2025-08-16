#import "Basic";
#import "Math";
ht :: #import "Hash_Table";

MESH_ASSET_COUNT :: 128; // Calculate this?

// Contains a linear database of all mesh assets on disk
Mesh_Asset :: struct {
	name		: string;
	asset_path	: string;
}

MESH_ASSETS :: [MESH_ASSET_COUNT]Mesh_Asset; 

Mesh_Entry :: struct {
	asset_idx	: u32;

}

Mesh_Instance :: struct {
	Mesh_ID		: u32;
	Transform	: Matrix4;
}

// Maps an entity's u64 tp a mesh proxy instance
Mesh_Instance_Table :: ht.Table(u64, Mesh_Instance, null, LOAD_FACTOR_PERCENT=70);