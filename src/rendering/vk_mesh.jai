#import "cgltf";

GEOPOOL_VERTEX_ALLOC_SIZE :: 64 * 1024 * 1024;
GEOPOOL_INDEX_ALLOC_SIZE :: 64 * 1024 * 1024;

// This contains the raw data for the loaded meshes, and is owned by the ZRenderer
GPU_Geometry_Pool :: struct {
	vertex_buffer			: Allocated_Buffer;
	index_buffer			: Allocated_Buffer;
	vertex_buffer_address 	: VkDeviceAddress;
	index_buffer_address	: VkDeviceAddress;

	vertex_offset			: u64;
	index_offset			: u64;

	vertex_capacity			: u64;
	index_capacity			: u64;

	init :: (using self: *GPU_Geometry_Pool, device: VkDevice, allocator: VmaAllocator, vertex_alloc_size: u64, index_alloc_size: u64, debug_name: string = "") {
		vertex_buffer = create_buffer(allocator, vertex_alloc_size, 
										.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | .VK_BUFFER_USAGE_TRANSFER_DST_BIT | .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, 
										.VMA_MEMORY_USAGE_GPU_ONLY, device, "Vertex Geometry Pool");
		queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, vertex_buffer.buffer, vertex_buffer.allocation);

		index_buffer = create_buffer(allocator, index_alloc_size, 
										.VK_BUFFER_USAGE_INDEX_BUFFER_BIT | .VK_BUFFER_USAGE_TRANSFER_DST_BIT | .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, 
										.VMA_MEMORY_USAGE_GPU_ONLY, device, "Index Geometry Pool");
		queue_deletion(*GLOBAL_DELETION_QUEUE, VMA_ALLOCATOR, index_buffer.buffer, index_buffer.allocation);

		vertex_buffer_info : VkBufferDeviceAddressInfo;
		vertex_buffer_info.sType = .VK_STRUCTURE_TYPE_BUFFER_DEVICE_ADDRESS_INFO;
		vertex_buffer_info.buffer = vertex_buffer.buffer;
		vertex_buffer_address = vkGetBufferDeviceAddress(device, *vertex_buffer_info);

		index_address_info : VkBufferDeviceAddressInfo;
		index_address_info.sType = .VK_STRUCTURE_TYPE_BUFFER_DEVICE_ADDRESS_INFO;
		index_address_info.buffer = index_buffer.buffer;
		index_buffer_address = vkGetBufferDeviceAddress(device, *index_address_info);

		vertex_offset = 0;
        index_offset = 0;
        vertex_capacity = vertex_alloc_size;
        index_capacity = index_alloc_size;
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

load_glt_meshes :: (zr: *ZRenderer, file_path: string) -> []string {
	loaded_mesh_names : [..]string;

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

	meshes		: [..]*Mesh_Asset;
	indices		: [..]u32;
	vertices	: [..]Vertex;

	mesh_count := data.meshes_count;

	for mesh_index: 0..mesh_count-1 {
		mesh := data.meshes[mesh_index];
		
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
	
			for vertex_idx: 0..vertex_count-1 {
				vertex : Vertex;

				// Position
				position : [3]float32;
				cgltf_accessor_read_float(position_accessor, vertex_idx, position.data, 3);
				vertex.position.x = position[0];
				vertex.position.y = position[1];
				vertex.position.z = position[2];

				// Normal
				if normal_accessor {
					normal : [3]float32;
					cgltf_accessor_read_float(normal_accessor, vertex_idx, normal.data, 3);
					vertex.normal.x = normal[0];
                    vertex.normal.y = normal[1];
                    vertex.normal.z = normal[2];
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
                    //vertex.tangent.x = tangent[0];
                   	//vertex.tangent.y = tangent[1];
                    //vertex.tangent.z = tangent[2];
                   
                }
                
                array_add(*vertices, vertex);
			}

			override_colors := true;
			if override_colors {
				for *vertices {
					it.color = .{it.normal.x, it.normal.y, it.normal.z, 1};
				}
			}

			new_surface := upload_mesh(zr, *zr.geometry_pool, indices, vertices);
			// TODO: set material?
			array_add(*new_mesh.surfaces, new_surface);

			array_reset(*indices);
            array_reset(*vertices);
		} 
		
		array_add(*zr.meshes, new_mesh);
		mesh_ptr := *zr.meshes[zr.meshes.count - 1];
		table_add(*zr.mesh_map, mesh_ptr.name, mesh_ptr);
		array_add(*loaded_mesh_names, mesh_ptr.name);
	}
	return loaded_mesh_names;
}

upload_mesh :: (zr: *ZRenderer, pool: *GPU_Geometry_Pool, indices: []u32, vertices: []Vertex) -> Geo_Surface {
	if vertices.count == 0 || indices.count == 0 {
		print("WARNING: Trying to upload empty mesh\n");
		return .{};  
	}
	vertex_size := vertices.count * size_of(Vertex);
	index_size := indices.count * size_of(u32);

	if pool.vertex_offset + xx vertex_size >= pool.vertex_capacity {
		panic(sprint("Attempted to allocate vertex chunk of size %, but the pool is full", vertex_size));
	}
	if pool.index_offset + xx index_size >= pool.index_capacity {
		panic(sprint("Attempted to allocate index chunk of size %, but the pool is full", index_size));
	}
	
	staging : Allocated_Buffer = create_buffer(VMA_ALLOCATOR, xx (vertex_size + index_size), .VK_BUFFER_USAGE_TRANSFER_SRC_BIT, .VMA_MEMORY_USAGE_CPU_ONLY, zr.device, "Mesh Staging Buffer");

	data : *void = staging.info.pMappedData;

	// Save these for later, we need them to init the addresses 
	vertex_offset := pool.vertex_offset;
	index_offset := pool.index_offset;

	memcpy(data, vertices.data, vertex_size); // Vertices into data
	memcpy(cast,no_check(*u8)data + vertex_size, indices.data, index_size); // Indices into data at the offset of vertex size

	immediate_submit(zr, #code {
		vertex_copy: VkBufferCopy;
		vertex_copy.dstOffset = pool.vertex_offset;
		vertex_copy.srcOffset = 0;
		vertex_copy.size = cast,no_check(u64) vertex_size;
		vkCmdCopyBuffer(cmd, staging.buffer, pool.vertex_buffer.buffer, 1, *vertex_copy);
    
		index_copy: VkBufferCopy;
		index_copy.dstOffset = pool.index_offset;
		index_copy.srcOffset = cast,no_check(u64) vertex_size;
		index_copy.size = cast,no_check(u64) index_size;
		vkCmdCopyBuffer(cmd, staging.buffer, pool.index_buffer.buffer, 1, *index_copy);
	});

	destroy_buffer(VMA_ALLOCATOR, *staging);

	pool.vertex_offset += xx vertex_size;
	pool.index_offset += xx index_size;

	surface : Geo_Surface;
	surface.vertex_address = pool.vertex_buffer_address + vertex_offset;
	surface.vertex_count = xx vertices.count;
	surface.index_address = pool.index_buffer_address + index_offset;
	surface.index_count = xx indices.count;
	surface.pool = pool;

	return surface;
}
