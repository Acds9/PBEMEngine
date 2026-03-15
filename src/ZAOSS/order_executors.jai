order_executor_set_thrust :: (world: *ZWorld, order: *Order, thrust: float32) {
	thrust_component, thrust_found := get_entity_component(world, order.entity, Thrust);
	if !thrust_found {
		archetype := get_archetype_type(order.entity.archetype);
		print("WARNING: Order executor attempted to fetch Thrust component in entity % of archetype %, but none was found\n", order.entity, archetype);
		return;
	}
	thrust_component.value = thrust;
}
order_executor_set_torque :: (world: *ZWorld, order: *Order, torque: float32) {
	torque_component, torque_found := get_entity_component(world, order.entity, Rotational_Velocity);
	if !torque_found {
		archetype := get_archetype_type(order.entity.archetype);
		print("WARNING: Order executor attempted to fetch Rotational Velocity component in entity % of archetype %, but none was found\n", order.entity, archetype);
		return;
	}
	torque_component.value.z = torque;
}