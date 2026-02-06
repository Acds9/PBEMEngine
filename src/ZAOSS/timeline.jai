Timeline_Step :: struct {
	index	: u32;
	orders	: [..]Order;
}

Turn_Timeline :: struct {
	timeline		: [..]Timeline_Step;

	step_start		: u32;
	step_count		: u32; 
	duration 		: float32;

	current_step	: u32;
	current_time	: float32;
}

initialize_timeline :: (timeline: *Turn_Timeline, step_start: u32, step_end: u32) {
	array_resize(*timeline.timeline, step_end-step_start);
}
