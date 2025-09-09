#import "cgltf";

Geo_Surface :: struct {
	start_index	: u32;
	count		: u64;
}

Mesh_Asset :: struct {
	name			: string;
	surfaces		: [..]Geo_Surface;
	mesh_buffers	: GPU_Mesh_Buffers;
}

Mesh_Handle :: struct {
	handle: u32;
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

			new_surface : Geo_Surface;
			new_surface.start_index = xx indices.count; // These aren't reset between primitives, just meshes
			
			initial_vertex : s64 = vertices.count; // Again, need to keep going across loops


			// Indices
			index_accessor : *cgltf_accessor = primitive.indices;
			new_surface.count = index_accessor.count;
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

			array_add(*new_mesh.surfaces, new_surface);
		} 

		override_colors := true;
		if override_colors {
			for *vertices {
				it.color = .{it.normal.x, it.normal.y, it.normal.z, 1};
			}
		}
		
		new_mesh.mesh_buffers = upload_mesh(zr, indices, vertices);

		array_add(*zr.meshes, new_mesh);
		mesh_ptr := *zr.meshes[zr.meshes.count - 1];
		table_add(*zr.mesh_map, mesh_ptr.name, mesh_ptr);
		array_add(*loaded_mesh_names, mesh_ptr.name);
	}
	return loaded_mesh_names;
}

upload_mesh :: (zr: *ZRenderer, indices: []u32, vertices: []Vertex) -> GPU_Mesh_Buffers {

	if vertices.count == 0 || indices.count == 0 {
			print("WARNING: Trying to upload empty mesh\n");
			return .{};  
		}
	vertex_buffer_size : s64 = vertices.count * size_of(Vertex);
	index_buffer_size : s64 = indices.count * size_of(u32);

	new_surface : GPU_Mesh_Buffers;

	new_surface.vertex_buffer = create_buffer(zr, xx vertex_buffer_size, .VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | .VK_BUFFER_USAGE_TRANSFER_DST_BIT | .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT, .VMA_MEMORY_USAGE_GPU_ONLY, "Mesh Vertex Buffer");
	
	device_address_info : VkBufferDeviceAddressInfo;
	device_address_info.sType = .VK_STRUCTURE_TYPE_BUFFER_DEVICE_ADDRESS_INFO;
	device_address_info.buffer = new_surface.vertex_buffer.buffer;
	new_surface.vertex_buffer_address = vkGetBufferDeviceAddress(zr.logical_device, *device_address_info);

	new_surface.index_buffer = create_buffer(zr, xx index_buffer_size, .VK_BUFFER_USAGE_INDEX_BUFFER_BIT | .VK_BUFFER_USAGE_TRANSFER_DST_BIT, .VMA_MEMORY_USAGE_GPU_ONLY, "Mesh Index Buffer");

	staging : Allocated_Buffer = create_buffer(zr, xx (vertex_buffer_size + index_buffer_size), .VK_BUFFER_USAGE_TRANSFER_SRC_BIT, .VMA_MEMORY_USAGE_CPU_ONLY, "Mesh Staging Buffer");

	data : *void = staging.info.pMappedData;

	memcpy(data, vertices.data, vertex_buffer_size);
	memcpy(cast,no_check(*u8)data + vertex_buffer_size, indices.data, index_buffer_size);

	immediate_submit(zr, #code {
		vertex_copy: VkBufferCopy;
		vertex_copy.dstOffset = 0;
		vertex_copy.srcOffset = 0;
		vertex_copy.size = cast,no_check(u64) vertex_buffer_size;
		vkCmdCopyBuffer(cmd, staging.buffer, new_surface.vertex_buffer.buffer, 1, *vertex_copy);
    
		index_copy: VkBufferCopy;
		index_copy.dstOffset = 0;
		index_copy.srcOffset = cast,no_check(u64) vertex_buffer_size;
		index_copy.size = cast,no_check(u64) index_buffer_size;
		vkCmdCopyBuffer(cmd, staging.buffer, new_surface.index_buffer.buffer, 1, *index_copy);
	});

	destroy_buffer(zr.allocator, *staging);
	return new_surface;
}
