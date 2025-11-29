#import "cgltf";

GEOPOOL_VERTEX_ALLOC_SIZE :: 64 * 1024 * 1024;
GEOPOOL_INDEX_ALLOC_SIZE :: 64 * 1024 * 1024;
GEOPOOL_AABB_ALLOC_SIZE :: 8 * 1024 * 1024; // TODO: way too big at 8MB
GEOPOOL_GEO_SURFACE_ALLOC_SIZE :: 8 * 1024 * 1024; // ^

MAX_GEO_SURFACES :: 8;

GLTF_TO_ZENGINE_COORDINATES :: Matrix4.{
    0,  0,  1,  0,   // glTF Z to ZEngine X
   -1,  0,  0,  0,   // glTF -X to  ZEngine Y
    0,  1,  0,  0,   // glTF Y to  ZEngine Z
    0,  0,  0,  1
};

// This contains the raw data for the loaded meshes, and is owned by the ZRenderer. 
// Vertex and Index are NOT Uniform_Storage_Buffers because mesh vertex/index SETS are not uniform, even if vertices/indices are, making freelist etc pointless
Geometry_Pool :: struct {
	vertex_buffer			: Storage_Buffer;
	index_buffer			: Storage_Buffer;

	geo_surface_buffer		: Staged_Uniform_Storage_Buffer;
	default_aabb_buffer		: Staged_Uniform_Storage_Buffer; // Stores defaults, any per-instance AABBs will be stored in ZScene

	init :: (using self: *Geometry_Pool, device: VkDevice, allocator: VmaAllocator) {
		vertex_buffer = make_storage_buffer(allocator, GEOPOOL_VERTEX_ALLOC_SIZE, 
										.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT | .VK_BUFFER_USAGE_TRANSFER_DST_BIT | .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, 
										.VMA_MEMORY_USAGE_GPU_ONLY, device, "Vertex Geometry Pool");
		queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, vertex_buffer.buffer, vertex_buffer.allocation);

		index_buffer = make_storage_buffer(allocator, GEOPOOL_INDEX_ALLOC_SIZE, 
										.VK_BUFFER_USAGE_INDEX_BUFFER_BIT | .VK_BUFFER_USAGE_TRANSFER_DST_BIT | .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, 
										.VMA_MEMORY_USAGE_GPU_ONLY, device, "Index Geometry Pool");
		queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, index_buffer.buffer, index_buffer.allocation);

		geo_surface_buffer = make_staged_uniform_storage_buffer(allocator, GEOPOOL_AABB_ALLOC_SIZE, size_of(Geo_Surface),
										.VK_BUFFER_USAGE_INDEX_BUFFER_BIT | .VK_BUFFER_USAGE_TRANSFER_DST_BIT | .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, 
										device, "geo_surface buffer");
		queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, *geo_surface_buffer);

		default_aabb_buffer = make_staged_uniform_storage_buffer(allocator, GEOPOOL_GEO_SURFACE_ALLOC_SIZE, size_of(AABB),
										.VK_BUFFER_USAGE_INDEX_BUFFER_BIT | .VK_BUFFER_USAGE_TRANSFER_DST_BIT | .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, 
										device, "default AABB buffer");
		queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, *default_aabb_buffer);
	}

	transfer :: (using self: *Geometry_Pool, cmd: VkCommandBuffer) {
		geo_surface_buffer.transfer(*geo_surface_buffer, cmd);
		default_aabb_buffer.transfer(*default_aabb_buffer, cmd);
	}
}

Geo_Surface :: struct {
	idx_vertex		: u32;
	vertex_count	: u32;
	idx_index		: u32;
	index_count		: u32;

	default_material_instance : u32;
}

DEFAULT_MATERIAL_OVERRIDES :: #run -> [MAX_GEO_SURFACES]u32 {
    result: [MAX_GEO_SURFACES]u32;
    for i: 0..MAX_GEO_SURFACES-1 {
        result[i] = U32_MAX;
    }
    return result;
};

Mesh_Instance :: struct {
	material_overrides	: [MAX_GEO_SURFACES]u32 = DEFAULT_MATERIAL_OVERRIDES;
	idx_mesh_asset		: u32; 
	idx_transform		: u32;
	idx_aabb			: u32;
	idx_geo_surface		: u32; 
	geo_surface_count	: u8;
	generation			: u8;
}

// CPU side representation of a full mesh asset
Mesh_Asset :: struct { 
	name					: string;
	mesh_index				: u32;
	idx_geo_surface			: u32;
	idx_aabb				: u32;
	geo_surface_count		: u8;
}

get_mesh_geo_surface :: (zr: *ZRenderer, mesh: *Mesh_Asset, surface_idx: u32) -> *Geo_Surface {
	surface_buffer := *zr.geometry_pool.geo_surface_buffer;
	surfaces := cast,no_check(*Geo_Surface)surface_buffer.staging_buffer.info.pMappedData;
	return *surfaces[mesh.idx_geo_surface + surface_idx];
}

load_glt_mesh :: (zr: *ZRenderer, file_path: string) -> *Mesh_Asset {
	filetype_found, left, filetype := split_from_right(file_path, ".");
	if filetype_found && filetype != "glb" {
		print("ERROR: Trying to load mesh from non-glb file, but only glb is supported.\n");
		return null;
	}
	options		: cgltf_options;
	data		: *cgltf_data;
	//buffers		: 
	result := cgltf_parse_file(*options, file_path.data, *data);
	if result != .success {
		panic(sprint("ERROR: failed to parse gltf file, reason: %\n", result));
	}
	defer{
		cgltf_free(data);
	}
	result = cgltf_load_buffers(*options, data, file_path.data);
	if result != .success {
        panic(sprint("ERROR: failed to load gltf buffers, reason: %\n", result));
    }

	indices		: [..]u32;
	vertices	: [..]Vertex;

	mesh_count := data.meshes_count;
	if mesh_count > 1 {
		print("WARNING: Trying to load mesh from glb file with more than 1 mesh, but this is not supported. All meshes after the 1st will be skipped.\n");
	}
	
	mesh := data.meshes[0];
		
	new_mesh : Mesh_Asset; // Temp on stack
	new_mesh.name = copy_string(to_string(mesh.name));
	new_mesh.idx_geo_surface = U32_MAX; // See bottom of mesh loading

	array_reset(*indices);
	array_reset(*vertices);

	aabb_min : Vector3 = .{FLOAT32_MAX, FLOAT32_MAX, FLOAT32_MAX};
	aabb_max : Vector3 = .{FLOAT32_MIN, FLOAT32_MIN, FLOAT32_MIN};

	for primitive_index: 0..mesh.primitives_count-1 {
		primitive := mesh.primitives[primitive_index];
			
		initial_vertex : s64 = vertices.count; // Again, need to keep going across loops

		// Indices
		index_accessor : *cgltf_accessor = primitive.indices;
		array_reserve(*indices, indices.count + xx index_accessor.count);

		for idx: 0..index_accessor.count-1 {
			index_value := cgltf_accessor_read_index(index_accessor, idx);
			array_add(*indices, xx index_value);
		}
			
		// Attribute accessors
		position_accessor 	:= cgltf_find_accessor(*primitive, .cgltf_attribute_type_position, 0);
		normal_accessor   	:= cgltf_find_accessor(*primitive, .cgltf_attribute_type_normal, 0);
		texcoord_accessor 	:= cgltf_find_accessor(*primitive, .cgltf_attribute_type_texcoord, 0); // 1, 2 etc for multiple UVs
		tangent_accessor  	:= cgltf_find_accessor(*primitive, .cgltf_attribute_type_tangent, 0);
		color_accessor		:= cgltf_find_accessor(*primitive, .cgltf_attribute_type_color, 0);
			
		if !position_accessor {
			print("WARNING: Primitive missing position attribute\n");
			continue;
		}

		vertex_count := position_accessor.count;
		initial_vertex_count := vertices.count;
		array_reserve(*vertices, vertices.count + xx vertex_count);
	
		// All coordinates are swizzled to convert from gltf2 to ZEngine
		for vertex_idx: 0..vertex_count-1 {
			vertex : Vertex;

			// Position
			position : [3]float32;
			cgltf_accessor_read_float(position_accessor, vertex_idx, position.data, 3);
			vertex.position.x = position[2];
			vertex.position.y = -position[0];
			vertex.position.z = position[1];

			aabb_min.x = min(aabb_min.x, vertex.position.x);
			aabb_min.y = min(aabb_min.y, vertex.position.y);
			aabb_min.z = min(aabb_min.z, vertex.position.z);

			aabb_max.x = max(aabb_max.x, vertex.position.x);
			aabb_max.y = max(aabb_max.y, vertex.position.y);
			aabb_max.z = max(aabb_max.z, vertex.position.z);

			// Normal
			if normal_accessor {
				normal : [3]float32;
				cgltf_accessor_read_float(normal_accessor, vertex_idx, normal.data, 3);
				vertex.normal.x = normal[2];
				vertex.normal.y = -normal[0];
				vertex.normal.z = normal[1];
			} else {
				vertex.normal = .{0, 1, 0};
			}

			// Texture coordinates
			if texcoord_accessor {
				texcoord: [2]float32;
				cgltf_accessor_read_float(texcoord_accessor, vertex_idx, texcoord.data, 2);
				vertex.uv_x = texcoord[0];
				vertex.uv_y = texcoord[1];
			} else {
				vertex.uv_x = 0;
				vertex.uv_y = 0;
			}

			// Texture coordinates
			if color_accessor {
				color: [4]float32;
				cgltf_accessor_read_float(color_accessor, vertex_idx, color.data, 4);
				vertex.color.x = color[0];
				vertex.color.y = color[1];
				vertex.color.z = color[2];
				vertex.color.w = color[3];
			} else {
				vertex.color = .{0,0,0,0};
			}

			// Tangent 
			if tangent_accessor {
				tangent: [4]float32;
				cgltf_accessor_read_float(tangent_accessor, vertex_idx, tangent.data, 4);
				//vertex.tangent.x = tangent[2];
				//vertex.tangent.y = -tangent[0];
				//vertex.tangent.z = tangent[1];
                   
			}
                
			vertex.color = .{1, 1, 1, 1};
			array_add(*vertices, vertex);
		}

		
		new_index := upload_surface(zr, *zr.geometry_pool, indices, vertices, zr.mi_default);

		// Somewhat ugly but this way we only set the first one
		if new_mesh.idx_geo_surface == U32_MAX {
			new_mesh.idx_geo_surface = new_index;
		}
		new_mesh.geo_surface_count += 1;
		
		if new_mesh.geo_surface_count > MAX_GEO_SURFACES {
			panic(sprint("Attempted to load mesh with more than MAX_GEO_SURFACES (currently %), either don't or increase MAX_GEO_SURFACES", MAX_GEO_SURFACES));
		}
		array_reset(*indices);
		array_reset(*vertices);
	}
	
	half_extents := (aabb_max - aabb_min) * 0.5;
	extents_center := (aabb_min + aabb_max) * 0.5;
	mesh_aabb := AABB.{extents_center, 0, half_extents, 0};
	
	new_mesh.idx_aabb = zr.geometry_pool.default_aabb_buffer.allocate(*zr.geometry_pool.default_aabb_buffer, mesh_aabb);
	
	new_mesh.mesh_index = xx zr.meshes.count;
	array_add(*zr.meshes, new_mesh);
	mesh_ptr := *zr.meshes[zr.meshes.count - 1];

	return mesh_ptr;
}

upload_surface :: (zr: *ZRenderer, pool: *Geometry_Pool, indices: []u32, vertices: []Vertex, mi_index: u32) -> u32 {
	if vertices.count == 0 || indices.count == 0 {
		print("WARNING: Trying to upload empty mesh\n");
		return U32_MAX;  
	}
	vertex_size := vertices.count * size_of(Vertex);
	index_size := indices.count * size_of(u32);

	if pool.vertex_buffer.offset + xx vertex_size >= pool.vertex_buffer.info.size {
		panic(sprint("Attempted to allocate vertex chunk of size %, but the pool is full", vertex_size));
	}
	if pool.index_buffer.offset + xx index_size >= pool.index_buffer.info.size {
		panic(sprint("Attempted to allocate index chunk of size %, but the pool is full", index_size));
	}
	
	staging : Allocated_Buffer = create_buffer(VMA_ALLOCATOR, xx (vertex_size + index_size), .VK_BUFFER_USAGE_TRANSFER_SRC_BIT, .VMA_MEMORY_USAGE_CPU_ONLY, zr.device, "Mesh Staging Buffer");

	data : *void = staging.info.pMappedData;

	// Calculate vertex offset in terms of vertex count (not bytes)
    vertex_idx := pool.vertex_buffer.offset / size_of(Vertex);
	index_idx := pool.index_buffer.offset / size_of(u32);

	memcpy(data, vertices.data, vertex_size); // Vertices into data
	memcpy(cast,no_check(*u8)data + vertex_size, indices.data, index_size); // Indices into data at the offset of vertex size

	immediate_submit(zr, #code {
		vertex_copy: VkBufferCopy;
		vertex_copy.dstOffset = pool.vertex_buffer.offset;
		vertex_copy.srcOffset = 0;
		vertex_copy.size = cast,no_check(u64) vertex_size;
		vkCmdCopyBuffer(cmd, staging.buffer, pool.vertex_buffer.buffer, 1, *vertex_copy);
    
		index_copy: VkBufferCopy;
		index_copy.dstOffset = pool.index_buffer.offset;
		index_copy.srcOffset = cast,no_check(u64) vertex_size;
		index_copy.size = cast,no_check(u64) index_size;
		vkCmdCopyBuffer(cmd, staging.buffer, pool.index_buffer.buffer, 1, *index_copy);
	});
	destroy_buffer(VMA_ALLOCATOR, *staging);

	pool.vertex_buffer.offset += xx vertex_size;
	pool.index_buffer.offset += xx index_size;

	surface : Geo_Surface;
	surface.idx_vertex = xx vertex_idx;
	surface.vertex_count = xx vertices.count;
	surface.idx_index = xx index_idx;
	surface.index_count = xx indices.count;
	surface.default_material_instance = mi_index;

	return pool.geo_surface_buffer.allocate(*pool.geo_surface_buffer, surface);
}
