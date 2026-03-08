Order :: struct @serialize {
	owner	: u64;
	entity	: ZEntity;
	type	: ORDER_TYPE;
	step	: u32;
	data_offset : s64;
	data_count	: s64; // TODO: if orders are interpreted by executors and they are always the same, do we need count? NO
}

Order_File :: struct @serialize {
	game	: string;
	turn	: u32;
	order_stream	: Order_Stream;
}

create_order :: (stream: *Order_Stream, owner: u64, entity: ZEntity, type: ORDER_TYPE, step: u32, data: *$T) {
	order := Order.{owner = owner, entity = entity, type = type, step = step};
	order.data_offset = serialize_to_buffer(*stream.data, data);
	order.data_count = size_of(T);
	array_add(*stream.orders, order);
	print("Created order % for entity % with data % at step %\n", type, entity, <<data, step);
}

save_orders :: (game: string, turn: u32) {
	path := get_order_directory(game);
	if ensure_directory_exists(path) {
		order_path := get_order_file_path(game, turn);
		data_buffer : [..]u8;
		defer free(data_buffer.data);

		serialize(*data_buffer, *GAME_INSTANCE.replay_system.order_file);
		write_entire_file(order_path, data_buffer.data, data_buffer.count);
	}
}

load_orders_to_stream :: (dest: *Order_Stream, src: *[..]Order_File, reset: bool = true) {
	if reset {
		array_reset(*dest.orders);
		array_reset(*dest.data);
	}

	// Calculate total sizes needed
	total_orders : s64;
	total_data : s64;
	for *file: <<src {
		total_orders += file.order_stream.orders.count;
		total_data += file.order_stream.data.count;
	}

	order_offset := dest.orders.count;
	data_offset := dest.data.count;
	array_resize(*dest.orders, order_offset + total_orders);
	array_resize(*dest.data, data_offset + total_data);

	for *file: <<src {
		for 0..file.order_stream.orders.count-1 {
			dest.orders[order_offset + it] = file.order_stream.orders[it];
			dest.orders[order_offset + it].data_offset += data_offset;
		}
		order_offset += file.order_stream.orders.count;

		memcpy(dest.data.data + data_offset, file.order_stream.data.data, file.order_stream.data.count);
		data_offset += file.order_stream.data.count;
	}

	quick_sort(dest.orders, (x) => x.step);
}

write_to_disk_order :: (src: *Order_File, path: string) {
	data_buffer : [..]u8;
	defer free(data_buffer.data);

	serialize(*data_buffer, src);
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
    deserialize(dest, xx contents, *offset);
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