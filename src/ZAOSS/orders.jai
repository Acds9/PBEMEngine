current_orders : Turn_Orders;

ORDER_TYPE :: enum u32 {
	SET_THRUST;
	SET_TORQUE;
}

Order :: struct {
	owner	: u64;
	entity	: ZEntity;
	type	: ORDER_TYPE;
	step	: u32;
	
	// For access into Turn_Orders.data
	data_idx 	: u64; 
	data_size 	: s64;
	// This is only used when a player is giving orders, any other time this data is compacted into Turn_Orders.data
	data		: [..]u8;
}

Turn_Orders :: struct {
	owner	: u64;
	turn	: u32;
	game	: u64;
	orders	: [..]Order;
	data	: [..]u8;
}

create_order :: (orders: *Turn_Orders, owner: u64, entity: ZEntity, type: ORDER_TYPE, step: u32, data: *$T) {
	order := Order.{owner = owner, entity = entity, type = type, step = step, data_idx = 0, data_size = size_of(T)};
	serialize_to_buffer(*order.data, data, size_of(T));
	array_add(*orders.orders, order);
}

serialize_order :: (order: *Order, dest: *[..]u8, data_dest: *[..]u8, write_idx: *s64) {
	serialize_to_buffer(dest, *order.owner, write_idx, size_of(u64));
	serialize_to_buffer(dest, *order.entity, write_idx, size_of(ZEntity));
	serialize_to_buffer(dest, *order.type, write_idx, size_of(ORDER_TYPE));
	serialize_to_buffer(dest, *order.step, write_idx, size_of(u32));


	data_idx := data_dest.count;
	serialize_to_buffer(dest, *data_idx, write_idx, size_of(u64));
	serialize_to_buffer(dest, *order.data_size, write_idx, size_of(s64));
	serialize_to_buffer(data_dest, order.data.data, *data_idx, order.data_size); // Write the data to the merged databuffer provided
}

serialize_orders :: (orders: *Turn_Orders, dest: *[..]u8) {
	write_idx : s64;
	serialize_to_buffer(dest, *orders.owner, *write_idx, size_of(u64));
	serialize_to_buffer(dest, *orders.turn, *write_idx, size_of(u32));
	serialize_to_buffer(dest, *orders.game, *write_idx, size_of(u64));
	serialize_to_buffer(dest, *orders.orders.count, *write_idx, size_of(s64));
	for *orders.orders {
		serialize_order(it, dest, *orders.data, *write_idx); // Pass the orders.data buffer so it can serialize straight to it
	}
	serialize_to_buffer(dest, *orders.data.count, *write_idx, size_of(s64));
	serialize_to_buffer(dest, orders.data.data, *write_idx, orders.data.count);
}

deserialize_order :: (data: []u8, read_offset: *s64) -> Order {
	order : Order;
	deserialize_from_buffer(*order.owner, data, read_offset, size_of(u64));
	deserialize_from_buffer(*order.entity, data, read_offset, size_of(ZEntity));
	deserialize_from_buffer(*order.type, data, read_offset, size_of(ORDER_TYPE));
	deserialize_from_buffer(*order.step, data, read_offset, size_of(u32));
	deserialize_from_buffer(*order.data_idx, data, read_offset, size_of(u64));
	deserialize_from_buffer(*order.data_size, data, read_offset, size_of(s64));
	return order;
}

deserialize_orders :: (data: []u8) -> Turn_Orders {
	orders : Turn_Orders;
	read_offset : s64;
	deserialize_from_buffer(*orders.owner, data, *read_offset, size_of(u64));
	deserialize_from_buffer(*orders.turn, data, *read_offset, size_of(u32));
	deserialize_from_buffer(*orders.game, data, *read_offset, size_of(u64));
	order_count : s64;
	deserialize_from_buffer(*order_count, data, *read_offset, size_of(s64));
	array_resize(*orders.orders, order_count);
	for 0..order_count-1 {
		orders.orders[it] = deserialize_order(data, *read_offset);
	}
	data_count : s64;
	deserialize_from_buffer(*data_count, data, *read_offset, size_of(s64));
	array_resize(*orders.data, data_count);
	memcpy(orders.data.data, data.data + read_offset, data_count);
	return orders;
}

save_orders :: (game: string, turn: u32) {
	cwd := get_working_directory();

	path := tprint("%/%/%", GAME_FOLDER_PATH, game, ORDER_FOLDER_NAME);
	if ensure_directory_exists(path) {
		order_path := tprint("%/%_%.order", path, game, turn);
		
		data_buffer : [..]u8;
		defer free(data_buffer.data);
		serialize_orders(*current_orders, *data_buffer);
		write_entire_file(order_path, data_buffer.data, data_buffer.count);
	}
}

load_orders_to_timeline :: (game: string, turn_timeline: *Turn_Timeline) {
	turn_orders	: [..]Turn_Orders;
	read_all_orders(get_order_directory(game), *turn_orders);
	step_bound_lower, step_bound_upper := turn_timeline.step_start, turn_timeline.step_end; 
	for *file: turn_orders {
		for *order: file.orders {
			if order.step < step_bound_lower || order.step > step_bound_upper {
				continue; // Most basic filtering of invalid orders, will need more
			}
			timeline_step : *Timeline_Step = *turn_timeline.steps[order.step];
			array_add(*timeline_step.orders, <<order);
			print("Order % added to timeline step %\n", order.type, timeline_step.index);
		}
	}

}