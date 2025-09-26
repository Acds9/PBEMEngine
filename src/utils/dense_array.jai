/*Dense_Array :: struct(type: $T) {
	data:	[..]T;
	free_list: [..]u32;

	add :: (using self: *Dense_Array($T), value: T) {
		idx : u32;
		if free_list.count > 0 {
			idx = pop(free_list);
			data[idx] = value;
			return idx;
		}
		else {
			array_add(*data, value);
			return data.count -1;
		}
	}
	remove :: (using self: *Dense_Array($T), index: u32) {
		array_add(*free_list, index);
	}
	is_live_index :: (using self: *Dense_Array($T), index: u32) -> bool {
		for free_list { // Implement generations if this becomes a perf issue
			if index == it {
				return false;
			}
		}
		return true;
	}
}*/