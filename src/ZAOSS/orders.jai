current_orders : Turn_Timeline;

Order :: struct {
	owner	: u64;
	entity	: ZEntity;
	type	: ORDER_TYPE;
	step	: u32;
	data	: [..]u8;
}

Order_File :: struct {
	game	: string;
	turn	: u32;
	timeline: Turn_Timeline;
}

create_order :: (timeline: *Turn_Timeline, owner: u64, entity: ZEntity, type: ORDER_TYPE, step: u32, data: *$T) {
	order := Order.{owner = owner, entity = entity, type = type, step = step};
	serialize_to_buffer(*order.data, *owner);
	serialize_to_buffer(*order.data, *entity);
	serialize_to_buffer(*order.data, data, size_of(T));
	timeline_step := *timeline.steps[step];
	array_add(*timeline_step.orders, order);
}

serialize_order :: (dest: *[..]u8, src: *Order) {
	serialize_to_buffer(dest, *src.owner);
	serialize_to_buffer(dest, *src.entity);
	serialize_to_buffer(dest, *src.type);
	serialize_to_buffer(dest, *src.step);

	serialize_to_buffer(dest, *src.data.count);
	serialize_to_buffer(dest, *src.data, src.data.count);
}

deserialize_order :: (dest: *Order, src: []u8, offset: *s64) {
	deserialize_from_buffer(*dest.owner, src, offset);
	deserialize_from_buffer(*dest.entity, src, offset);
	deserialize_from_buffer(*dest.type, src, offset);
	deserialize_from_buffer(*dest.step, src, offset);
	data_size : s64;
	deserialize_from_buffer(*data_size, src, offset);
	deserialize_from_buffer(*dest.data, src, offset, data_size);
}

serialize_order_file :: (dest: *[..]u8, src: *Order_File) {
	serialize_to_buffer_string(dest, src.game);
	serialize_to_buffer(dest, *src.turn);
	serialize_turn_timeline(dest, *src.timeline);
}

deserialize_order_file :: (dest: *Order_File, src: []u8, offset: *s64) {
	dest.game = deserialize_from_buffer_string(src, offset);
	deserialize_from_buffer(*dest.turn, src, offset);
	deserialize_turn_timeline(*dest.timeline, src, offset);
}

save_orders :: (game: string, turn: u32) {
	path := get_order_directory(game);
	if ensure_directory_exists(path) {
		order_path := get_order_file_path(game, turn);
		data_buffer : [..]u8;
		defer free(data_buffer.data);

		order_file : Order_File;
		order_file.game = game;
		order_file.turn = turn;
		order_file.timeline = current_orders; // TODO: not great to copy, but probably doesn't matter
		serialize_order_file(*data_buffer, *order_file);
		write_entire_file(order_path, data_buffer.data, data_buffer.count);
	}
}

load_orders_to_timeline :: (dest: *Turn_Timeline, src: *[..]Order_File) {
	step_bound_lower, step_bound_upper := dest.step_start, dest.step_end; 
	for *file: <<src {
		for *step: file.timeline.steps {
			for *order: step.orders {
				if order.step < step_bound_lower || order.step > step_bound_upper {
					continue; // Most basic filtering of invalid orders, will need more
				}
				timeline_step : *Timeline_Step = *dest.steps[order.step];
				array_add(*timeline_step.orders, <<order);
				print("Order % added to timeline step %\n", order.type, timeline_step.index);
			}
			
		}
	}

}

write_to_disk_order :: (src: *Order_File, path: string) {
	data_buffer : [..]u8;
	defer free(data_buffer.data);

	serialize_order_file(*data_buffer, src);
	write_entire_file(path, data_buffer.data, data_buffer.count);
}

write_to_disk_order :: (src: *Order_File) {
	path := get_order_file_path(src.game, src.turn);
	write_to_disk_order(src, path);
}

read_from_disk_order :: (dest: *Order_File, path: string) {
	contents, success := read_entire_file(path);
    assert(success, "Could not read order at path %\n", path);
	offset : s64;
    deserialize_order_file(dest, xx contents, *offset);
}

read_from_disk_order :: (dest: *Order_File, game: string, turn: u32) {
	path := get_order_file_path(game, turn);
    read_from_disk_order(dest, path);
}

read_from_disk_orders :: (dest: *[..]Order_File, folder: string) {
	print("Received path: %\n", folder);
	order_paths := file_list_ext(folder, "order", true);
	defer free(order_paths.data);

	if dest.count < order_paths.count {
		array_resize(dest, order_paths.count);
	}

	if !order_paths.count {
		print("WARNING: No order files found in folder %\n", folder);
		return;
	}
	array_resize(dest, order_paths.count);
	for path: order_paths {
		read_from_disk_order(*(<<dest)[it_index], path);
	}
}