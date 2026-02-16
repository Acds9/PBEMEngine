order_executor_set_thrust :: (world: *ZWorld, owner: u64, entity: ZEntity, thrust: float32) {
	thrust_component, thrust_found := get_entity_component(world, entity, Thrust);
	if !thrust_found {
		archetype := get_archetype(entity.archetype);
		print("WARNING: Order executor attempted to fetch Thrust component in entity % of archetype %, but none was found\n", entity, archetype);
	}
	thrust_component.value = thrust;
}