#import "cgltf";

GEOPOOL_VERTEX_ALLOC_SIZE :: 64 * 1024 * 1024;
GEOPOOL_INDEX_ALLOC_SIZE :: 64 * 1024 * 1024;

GLTF_TO_ZENGINE_COORDINATES :: Matrix4.{
    0,  0,  1,  0,   // glTF Z to ZEngine X
   -1,  0,  0,  0,   // glTF -X to  ZEngine Y
    0,  1,  0,  0,   // glTF Y to  ZEngine Z
    0,  0,  0,  1
};

// This contains the raw data for the loaded meshes, and is owned by the ZRenderer. It is not a Uniform_Storage_Buffer because meshe vertex/index SETS are not uniform, even if vertices/indices are
GPU_Geometry_Pool :: struct {
	vertex_buffer			: Storage_Buffer;
	index_buffer			: Storage_Buffer;

	init :: (using self: *GPU_Geometry_Pool, device: VkDevice, allocator: VmaAllocator, vertex_alloc_size: u64, index_alloc_size: u64, debug_name: string = "") {
		vertex_buffer = make_storage_buffer(allocator, vertex_alloc_size, 
										.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT | .VK_BUFFER_USAGE_TRANSFER_DST_BIT | .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, 
										.VMA_MEMORY_USAGE_GPU_ONLY, device, "Vertex Geometry Pool");
		queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, vertex_buffer.buffer, vertex_buffer.allocation);

		index_buffer = make_storage_buffer(allocator, index_alloc_size, 
										.VK_BUFFER_USAGE_INDEX_BUFFER_BIT | .VK_BUFFER_USAGE_TRANSFER_DST_BIT | .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, 
										.VMA_MEMORY_USAGE_GPU_ONLY, device, "Index Geometry Pool");
		queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, index_buffer.buffer, index_buffer.allocation);
	}
}

Geo_Surface :: struct {
	// Offsets into shared pool
	vertex_address	: VkDeviceAddress; // TODO: why call them address if they are offsets?
	vertex_count	: u32;
	index_address	: VkDeviceAddress;
	index_count		: u32;

	pool			: *GPU_Geometry_Pool;

	material	: *Material_Instance;
}

Mesh_Asset :: struct {
	name			: string;
	surfaces		: [..]Geo_Surface;
}

load_glt_meshes :: (zr: *ZRenderer, file_path: string) -> *Mesh_Asset {
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

	array_reset(*indices);
	array_reset(*vertices);
	
	primitive_count := mesh.primitives_count;

	for primitive_index: 0..primitive_count-1 {
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

		new_surface := upload_mesh(zr, *zr.geometry_pool, indices, vertices);
		new_surface.material = *zr.default_material;
		// TODO: need to load the actual material
		array_add(*new_mesh.surfaces, new_surface);

		array_reset(*indices);
		array_reset(*vertices);
	}
	array_add(*zr.meshes, new_mesh);
	mesh_ptr := *zr.meshes[zr.meshes.count - 1];

	return mesh_ptr;
}

upload_mesh :: (zr: *ZRenderer, pool: *GPU_Geometry_Pool, indices: []u32, vertices: []Vertex) -> Geo_Surface {
	if vertices.count == 0 || indices.count == 0 {
		print("WARNING: Trying to upload empty mesh\n");
		return .{};  
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

	// Save these for later, we need them to init the addresses 
	vertex_offset := pool.vertex_buffer.offset;
	index_offset := pool.index_buffer.offset;

	 // Calculate vertex offset in terms of vertex count (not bytes)
    vertex_count_offset := pool.vertex_buffer.offset / size_of(Vertex);

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
	surface.vertex_address = pool.vertex_buffer.base_address + vertex_offset;
	surface.vertex_count = xx vertices.count;
	surface.index_address = pool.index_buffer.base_address + index_offset;
	surface.index_count = xx indices.count;
	surface.pool = pool;

	return surface;
}
