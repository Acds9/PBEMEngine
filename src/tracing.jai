Ray_Intersection_Data :: struct {
	t				: float32;
	hit_location	: Vector3;
}

ray_box_intersect :: (ray_origin: Vector3, ray_dir: Vector3, bounds: *Volume_Bounds) -> bool, Ray_Intersection_Data {
    inv_dir := Vector3.{1.0 / ray_dir.x, 1.0 / ray_dir.y, 1.0 / ray_dir.z};

    hit, data, _ := ray_box_intersect_fast(ray_origin, ray_dir, inv_dir, bounds);
    return hit, data;
}

// Returns hit, intersection data, entry_t
// entry_t = max(tmin, 0) —> the earliest point this box could contain a hit from the ray origin
ray_box_intersect_fast :: (ray_origin: Vector3, ray_dir: Vector3, inv_dir: Vector3, bounds: *Volume_Bounds) -> bool, Ray_Intersection_Data, float32 {
    t1 := (bounds.min.x - ray_origin.x) * inv_dir.x;
    t2 := (bounds.max.x - ray_origin.x) * inv_dir.x;
    t3 := (bounds.min.y - ray_origin.y) * inv_dir.y;
    t4 := (bounds.max.y - ray_origin.y) * inv_dir.y;
    t5 := (bounds.min.z - ray_origin.z) * inv_dir.z;
    t6 := (bounds.max.z - ray_origin.z) * inv_dir.z;

    tmin := max(max(min(t1, t2), min(t3, t4)), min(t5, t6));
    tmax := min(min(max(t1, t2), max(t3, t4)), max(t5, t6));

    if tmax < 0 || tmin > tmax {
        return false, .{}, 0;
    }

    entry_t := max(tmin, 0.0);
    t := ifx tmin < 0 then tmax else tmin;
    return true, .{
        t = t,
        hit_location = ray_origin + ray_dir * t
    }, entry_t;
}

trace_ray :: (using system: *LBVH_System, ray_origin: Vector3, ray_dir: Vector3) -> bool, ZEntity {
    leaf_count := cast(u32) morton_codes.count;

    if leaf_count == 0 {
		return false, ENTITY_NONE;
	}

    ray_inv_dir := Vector3.{1.0 / ray_dir.x, 1.0 / ray_dir.y, 1.0 / ray_dir.z};

    if leaf_count == 1 {
        hit, _, entry_t := ray_box_intersect_fast(ray_origin, ray_dir, ray_inv_dir, *morton_codes[0].bounds);
        if hit return true, morton_codes[0].entity;
        return false, ENTITY_NONE;
    }

    // Stack traversal
    stack: [64]u32;  // 64 is reasonable
    stack_ptr := 0;
    stack[stack_ptr] = 0;  // Start at root
    stack_ptr += 1;

    closest_t := FLOAT32_MAX;
    closest_entity: ZEntity = ENTITY_NONE;

    while stack_ptr > 0 {
        stack_ptr -= 1;
        node_idx := stack[stack_ptr];

        node := *internal_nodes[node_idx];

        hit, _, entry_t := ray_box_intersect_fast(ray_origin, ray_dir, ray_inv_dir, *node.bounds);
        if !hit || entry_t >= closest_t continue;  // Miss or can't contain anything closer than best hit

        // Check children
        for child: u32.[node.left_child, node.right_child] {
            if child < leaf_count {
                // Leaf
                aabb_hit, _, aabb_entry_t := ray_box_intersect_fast(ray_origin, ray_dir, ray_inv_dir, *morton_codes[child].bounds);
                if aabb_hit && aabb_entry_t < closest_t {
                    closest_t = aabb_entry_t;
                    closest_entity = morton_codes[child].entity;
                }
            } else {
                // Internal node
                stack[stack_ptr] = child - leaf_count;
                stack_ptr += 1;
            }
        }
    }
    
    return closest_entity.index != ENTITY_NONE.index, closest_entity;
}

screen_to_ray :: (pos_x: s32, pos_y: s32, screen_width: s32, screen_height: s32, view_proj: *Matrix4) -> (origin: Vector3, direction: Vector3) {
    ndc_x := (2.0 * cast,no_check(float32)pos_x / cast,no_check(float32)screen_width) - 1.0;
	ndc_y := (2.0 * cast,no_check(float32)pos_y / cast,no_check(float32)screen_height) - 1.0;    

    near_clip := Vector4.{ndc_x, ndc_y, 1.0, 1.0}; 
	far_clip  := Vector4.{ndc_x, ndc_y, 0.0, 1.0};  
    
    inv_vp := inverse(transpose(<<view_proj));
    
    near_world := inv_vp * near_clip;
    far_world  := inv_vp * far_clip;
    
    near_world /= near_world.w;
    far_world  /= far_world.w;
    
    origin := Vector3.{near_world.x, near_world.y, near_world.z};
    direction := normalize(Vector3.{
        far_world.x - near_world.x,
        far_world.y - near_world.y,
        far_world.z - near_world.z
    });
    
    return origin, direction;
}