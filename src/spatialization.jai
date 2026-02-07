#import "Basic";
Math :: #import "Math";

BVH_Node :: struct {
    // If index < leaf_count it's a leaf otherwise subtract leafcount for internal node index
    left_child  : u32;
    right_child : u32;
    parent      : u32;
    
    bounds  : Volume_Bounds;
}


LBVH_System :: struct {
	scene_bounds 		: Volume_Bounds;
	scene_extents 		: Vector3;
	lane_bounds			: [..]Volume_Bounds;
	lane_entity_counts	: [..]u32;
	entity_count 		: u32;
	node_counters 		: [..]u32; // Per-node atomic counter, how many children have reported in

	Morton_Entity	:: struct {
		code	: u32;
		entity	: ZEntity;
		bounds	: Volume_Bounds;
	}
	morton_codes 	: [..]Morton_Entity;
	morton_src		: [..]Morton_Entity;
	morton_dst 		: [..]Morton_Entity;

	internal_nodes : [..]BVH_Node;  
    leaf_parents   : [..]u32;       // parent index for each leaf

	init :: (using self: *LBVH_System) {
		array_resize(*lane_bounds, context.lane_count);
		array_resize(*lane_entity_counts, context.lane_count);
	
	}
}

build_bvh :: (game_world: *Game_World) {
	system := *game_world.scene.bvh_system;
	compute_scene_bounds(game_world);
	if system.morton_codes.count <= 1 {
		return;
	}
	generate_morton_array(game_world);
	build_tree_topology(game_world);
	compute_bounding_boxes(game_world);
}

compute_scene_bounds :: (game_world: *Game_World) {
	using system := *game_world.scene.bvh_system;
	scene_min := Vector3.{FLOAT32_MAX, FLOAT32_MAX, FLOAT32_MAX};
	scene_max := Vector3.{-FLOAT32_MAX, -FLOAT32_MAX, -FLOAT32_MAX};

	lane_entity_counts[context.thread_index] = 0;  // Reset before counting

	execute_Query_Spatialize_Entities(*game_world.world, #code {
			if position.value.x < scene_min.x {
				scene_min.x = position.value.x;
			}
			if position.value.y < scene_min.y {
				scene_min.y = position.value.y;
			}
			if position.value.z < scene_min.z {
				scene_min.z = position.value.z;
			}

			if position.value.x > scene_max.x {
				scene_max.x = position.value.x;
			}
			if position.value.y > scene_max.y {
				scene_max.y = position.value.y;
			}
			if position.value.z > scene_max.z {
				scene_max.z = position.value.z;
			}
			lane_entity_counts[context.thread_index] += 1;
	});

	lane_bounds[context.thread_index] = .{scene_min, scene_max};
	barrier_wait(context.lane_barrier); // Make sure everyone is done
	

	// Work is duplicated, it's fine
	total_entity_count : u32;
	final_min := Vector3.{FLOAT32_MAX, FLOAT32_MAX, FLOAT32_MAX};
    final_max := Vector3.{-FLOAT32_MAX, -FLOAT32_MAX, -FLOAT32_MAX}; // FLOAT32_MIN is the smallest positive float, but we want smallest negative
	for i: 0..context.lane_count-1 {
		total_entity_count += lane_entity_counts[i];

        final_min.x = min(final_min.x, lane_bounds[i].min.x);
        final_min.y = min(final_min.y, lane_bounds[i].min.y);
        final_min.z = min(final_min.z, lane_bounds[i].min.z);
        final_max.x = max(final_max.x, lane_bounds[i].max.x);
        final_max.y = max(final_max.y, lane_bounds[i].max.y);
        final_max.z = max(final_max.z, lane_bounds[i].max.z);
    }
	narrow(#code{
		scene_bounds = .{final_min, final_max};
		scene_extents = scene_bounds.max - scene_bounds.min;
		array_resize(*morton_codes, total_entity_count);
	});

	barrier_wait(context.lane_barrier); 
}

compute_morton :: (position: *Vector3, scene_bounds : *Volume_Bounds, scene_extents : *Vector3) -> u32 {
	normalized := (<<position - scene_bounds.min) / scene_extents;

	// Clamped to handle floating point edge cases
	normalized.x = clamp(normalized.x, 0.0, 0.999999);
    normalized.y = clamp(normalized.y, 0.0, 0.999999);
    normalized.z = clamp(normalized.z, 0.0, 0.999999);

	// 10 bit quantization
	qx := cast,no_check(u32)(normalized.x * 1024);
	qy := cast,no_check(u32)(normalized.y * 1024);
	qz := cast,no_check(u32)(normalized.z * 1024);

	// Interleave
    return (expand_bits(qz) << 2) | (expand_bits(qy) << 1) | expand_bits(qx);
}

expand_bits :: (v: u32) -> u32 {
    // Spreads 10 bits across 30 bits with 2 zeros between each
    x := v & 0x3FF;
    x = (x | (x << 16)) & 0x030000FF;
    x = (x | (x <<  8)) & 0x0300F00F;
    x = (x | (x <<  4)) & 0x030C30C3;
    x = (x | (x <<  2)) & 0x09249249;
    return x;
}

generate_morton_array :: (game_world: *Game_World) {
	using system := *game_world.scene.bvh_system;
	execute_Query_Spatialize_Entities(*game_world.world, #code {
		mesh_data 		:= cast,no_check(*Mesh_Instance) game_world.scene.mesh_instances.staging_buffer.info.pMappedData;
		mesh_instance 	:= *mesh_data[mesh_render_proxy_ec.value];
		aabb_data 		:= cast,no_check(*AABB) ZRENDERER.geometry_pool.default_aabb_buffer.staging_buffer.info.pMappedData;
		aabb			:= *aabb_data[mesh_instance.idx_aabb];
		local_bounds := aabb_to_volume_bounds(aabb);
		world_bounds := Volume_Bounds.{
			local_bounds.min + position.value,
			local_bounds.max + position.value
		};
		morton_codes[query_counter] = .{compute_morton(*position.value, *scene_bounds, *scene_extents), current_entity, world_bounds};
	});

	// TODO: maybe this can be parallelized if needed, cache contention/invalidation might negate. Test?
	narrow(#code{
		array_resize(*morton_src, morton_codes.count);
		array_resize(*morton_dst, morton_codes.count);
		
		memcpy(morton_src.data, morton_codes.data, morton_codes.count * size_of(Morton_Entity));

		for pass: 0..2 {
			histogram: [1024]u32;  // zero initialized
    
			// Count
			for pair: morton_src {
				bucket := (pair.code >> (pass * 10)) & 0x3FF;
				histogram[bucket] += 1;
			}
    
			// Prefix sum -> offsets
			offsets: [1024]u32;
			running : u32 = 0;
			for i: 0..1023 {
				offsets[i] = running;
				running += histogram[i];
			}
    
			// Scatter
			for pair: morton_src {
				bucket := (pair.code >> (pass * 10)) & 0x3FF;
				morton_dst[offsets[bucket]] = pair;
				offsets[bucket] += 1;
			}
    
			// Swap
			tmp := morton_src;
			morton_src = morton_dst;
			morton_dst = tmp;
			//morton_src, morton_dst = morton_dst, morton_src;
		}
		memcpy(morton_codes.data, morton_src.data, morton_codes.count * size_of(Morton_Entity));
	});
	barrier_wait(context.lane_barrier);
}

delta :: (morton_codes: []LBVH_System.Morton_Entity, i: s32, j: s32) -> s32 {
    if j < 0 || j >= morton_codes.count return -1;
    
    xored := morton_codes[i].code ^ morton_codes[j].code;
    if xored == 0 {
        // Codes identical, use index to break tie
        return 30 + cast,no_check(s32) clz(xx,no_check(i ^ j));
    }
    return cast(s32) clz(xored);
}

clz :: (v: u32) -> u32 {
    // Count leading zeros and use intrinsic if available
    if v == 0 return 32;
    n : u32 = 0;
    if v <= 0x0000FFFF { n += 16; v <<= 16; }
    if v <= 0x00FFFFFF { n += 8;  v <<= 8;  }
    if v <= 0x0FFFFFFF { n += 4;  v <<= 4;  }
    if v <= 0x3FFFFFFF { n += 2;  v <<= 2;  }
    if v <= 0x7FFFFFFF { n += 1; }
    return n;
}

build_tree_topology :: (game_world: *Game_World) {
	using system := *game_world.scene.bvh_system;
    leaf_count := cast(s32) morton_codes.count;
	if leaf_count <= 1 {
		return;
	}
	narrow(#code{
		array_resize(*internal_nodes, leaf_count - 1);
		array_resize(*leaf_parents, leaf_count);
    });
	barrier_wait(context.lane_barrier);
    // Each internal node can be processed independently
	min, max := lane_range(xx,no_check(leaf_count - 1));
    for i: min..max {
        process_internal_node(game_world, cast(s32) i, leaf_count);
    }
}

process_internal_node :: (game_world: *Game_World, i: s32, leaf_count: s32) {
	using system := *game_world.scene.bvh_system;
    codes := morton_codes;
    
    // 1. Determine direction
    delta_left  := delta(codes, i, i - 1);
    delta_right := delta(codes, i, i + 1);
    d : s32 = xx,no_check ifx delta_right > delta_left then 1 else -1;
    
    // 2. Compute upper bound for range length
    delta_min := delta(codes, i, i - d);  // delta in opposite direction
    l_max : s32 = 2;
    while delta(codes, i, i + l_max * d) > delta_min {
        l_max *= 2;
    }
    
    // 3. Binary search for actual range length
    l : s32 = 0;
    t := l_max / 2;
    while t >= 1 {
        if delta(codes, i, i + (l + t) * d) > delta_min {
            l += t;
        }
        t /= 2;
    }
    j := i + l * d;  // other end of range
    
    // 4. Find split position
    delta_node := delta(codes, i, j);
    s : s32 = 0;
    t = (l + 1) / 2;
    while t >= 1 {
        test := i + (s + t) * d;
        if test >= 0 && test < leaf_count {
            if delta(codes, i, test) > delta_node {
                s += t;
            }
        }
        t /= 2;
    }
    split := i + s * d + min(d, 0);  // adjust for direction
    
    // 5. Assign children
    range_min := min(i, j);
    range_max := max(i, j);
    
    left_idx  : u32;
    right_idx : u32;

    // Left child
    if min(split, split + 1) == range_min {
        // Left child is a leaf
        left_idx = cast(u32) split;
        leaf_parents[split] = cast(u32) i;
    } else {
        // Left child is internal node
        left_idx = cast(u32) (leaf_count + split);
        internal_nodes[split].parent = cast(u32) i;
    }
    
    // Right child
    if max(split, split + 1) == range_max {
        // Right child is a leaf
        right_idx = cast(u32) (split + 1);
        leaf_parents[split + 1] = cast(u32) i;
    } else {
        // Right child is internal node
        right_idx = cast(u32) (leaf_count + split + 1);
        internal_nodes[split + 1].parent = cast(u32) i;
    }
    
    internal_nodes[i].left_child  = left_idx;
    internal_nodes[i].right_child = right_idx;
}

get_child_bounds :: (game_world: *Game_World, child_idx: u32, leaf_count: u32) -> *Volume_Bounds {
	using system := *game_world.scene.bvh_system;
    if child_idx < leaf_count {
        // Leaf
        return *morton_codes[child_idx].bounds;
    } else {
        // Internal node
        return *internal_nodes[child_idx - leaf_count].bounds;
    }
}

compute_bounding_boxes :: (game_world: *Game_World) {
	using system := *game_world.scene.bvh_system;
    leaf_count : u32 = xx,no_check morton_codes.count;
  
   	narrow(#code{
		array_resize(*node_counters, internal_nodes.count);
   		memset(node_counters.data, 0, node_counters.count * size_of(u32));
    });
	barrier_wait(context.lane_barrier);

    // Start from each leaf and walk up
    // Parallelizable one thread per leaf
	min, max := lane_range(leaf_count);
    for leaf_idx: min..max {
        // Get leaf bounds
        bounds := morton_codes[leaf_idx].bounds;
        
        parent_idx := leaf_parents[leaf_idx];
        
        while true {
            // Atomic increment returns old value
            count := atomic_add(*node_counters[parent_idx], 1);
            
            if count == 0 {
                break;
            }
            
            // Second child, both children done compute merged bounds
            node := *internal_nodes[parent_idx];
            left_bounds  := get_child_bounds(game_world, node.left_child, leaf_count);
            right_bounds := get_child_bounds(game_world, node.right_child, leaf_count);
            
            node.bounds.min = Math.min(left_bounds.min, right_bounds.min);
            node.bounds.max = Math.max(left_bounds.max, right_bounds.max);
            
			bounds = node.bounds;

            if parent_idx == 0 break;  // reached root
            parent_idx = node.parent;
        }
    }
}