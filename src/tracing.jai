Ray_Intersection_Data :: struct {
	t				: float32;
	hit_location	: Vector3;
}

ray_box_intersect :: (ray_origin: Vector3, ray_dir: Vector3, bounds: *Volume_Bounds) -> bool, Ray_Intersection_Data {
    inv_dir := Vector3.{1.0 / ray_dir.x, 1.0 / ray_dir.y, 1.0 / ray_dir.z};
    
	hit, data := ray_box_intersect_fast(ray_origin, ray_dir, inv_dir, bounds);
    return hit, data;
}

ray_box_intersect_fast :: (ray_origin: Vector3, ray_dir: Vector3, inv_dir: Vector3, bounds: *Volume_Bounds) -> bool, Ray_Intersection_Data {
    t1 := (bounds.min.x - ray_origin.x) * inv_dir.x;
    t2 := (bounds.max.x - ray_origin.x) * inv_dir.x;
    t3 := (bounds.min.y - ray_origin.y) * inv_dir.y;
    t4 := (bounds.max.y - ray_origin.y) * inv_dir.y;
    t5 := (bounds.min.z - ray_origin.z) * inv_dir.z;
    t6 := (bounds.max.z - ray_origin.z) * inv_dir.z;
    
    tmin := max(max(min(t1, t2), min(t3, t4)), min(t5, t6));
    tmax := min(min(max(t1, t2), max(t3, t4)), max(t5, t6));
    
    if tmax < 0 || tmin > tmax {
        return false, .{};
    }

    t := ifx tmin < 0 then tmax else tmin;
    return true, .{
        t = t,
        hit_location = ray_origin + ray_dir * t
    };
}

trace_ray :: (using system: *LBVH_System, ray_origin: Vector3, ray_dir: Vector3) -> ZEntity {
    leaf_count := cast(u32) morton_codes.count;
    
    // Stack traversal
    stack: [64]u32;  // 64 is reasonable
    stack_ptr := 0;
    stack[stack_ptr] = 0;  // Start at root
    stack_ptr += 1;
    
    closest_t := FLOAT32_MAX;
    closest_entity: ZEntity;

	ray_inv_dir := Vector3.{1.0 / ray_dir.x, 1.0 / ray_dir.y, 1.0 / ray_dir.z};
    
    while stack_ptr > 0 {
        stack_ptr -= 1;
        node_idx := stack[stack_ptr];
        
        node := *internal_nodes[node_idx];
        
		hit : bool;
		hit_data : Ray_Intersection_Data;
        hit, hit_data = ray_box_intersect_fast(ray_origin, ray_dir, ray_inv_dir, *node.bounds);
        if hit_data.t < 0 || hit_data.t >= closest_t continue;  // Miss or further than current hit
        
        // Check children
        for child: u32.[node.left_child, node.right_child] {
            if child < leaf_count {
                // Leaf
               	aabb_hit, aabb_data := ray_box_intersect_fast(ray_origin, ray_dir, ray_inv_dir, *morton_codes[child].bounds);
                if aabb_hit && aabb_data.t >= 0 && aabb_data.t < closest_t {
                    closest_t = aabb_data.t;
                    closest_entity = morton_codes[child].entity;
                }
            } else {
                // Internal node
                stack[stack_ptr] = child - leaf_count;
                stack_ptr += 1;
            }
        }
    }
    
    return closest_entity;
}

screen_to_ray :: (pos_x: s32, pos_y: s32, screen_width: s32, screen_height: s32, view: *Matrix4, projection: *Matrix4) -> (origin: Vector3, direction: Vector3) {
    // Normalized device coordinates
    ndc_x := (2.0 * cast,no_check(float32)pos_x / cast,no_check(float32)screen_width) - 1.0;
    ndc_y := 1.0 - (2.0 * cast,no_check(float32)pos_y / cast,no_check(float32)screen_height);  // Y flip
    
    // Clip space points on near and far plane
    near_clip := Vector4.{ndc_x, ndc_y, 0.0, 1.0};
    far_clip  := Vector4.{ndc_x, ndc_y, 1.0, 1.0};
    
    // Unproject to world space
    inv_vp := inverse(<<projection * <<view);
    
    near_world := inv_vp * near_clip;
    far_world  := inv_vp * far_clip;
    
    // Perspective divide
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