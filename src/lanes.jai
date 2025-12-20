#import "Thread";
#import "Atomics";
#import "System";
#add_context lane_count 		: u32;
#add_context lane_barrier 		: *Lane_Barrier;
#add_context lane_shared_buffer	: *[8]u8;

Lane_Barrier :: struct {
	count 		: u64;
	total 		: u64;
	generation 	: u64;

	lock:       CRITICAL_SECTION;
    cond:       CONDITION_VARIABLE;
}

Lane_System :: struct {
	lane_count 		: u32;
	lanes 			: [..]Thread;
	barrier 		: Lane_Barrier;
	shared_buffer	: [8]u8;

	init :: (using self: *Lane_System) {
		lane_total := get_number_of_processors(.ALL_LOGICAL); //TODO: This kind of work might do better with just physical, needs investigation

		// If we don't do this we're not including the main thread/lane and we break everything
		lane_count = xx lane_total;
		worker_count := lane_count - 1; 
		array_resize(*lanes, worker_count);

		barrier.total = lane_count;
		InitializeCriticalSection(*barrier.lock);
   		InitializeConditionVariable(*barrier.cond);

		for *lane: lanes {
			if !thread_init(lane, thread_entry) {
				panic(sprint("Failed to init lane %", it_index));
			}
			thread_start(lane);
		}
		
		print("Starting with % lanes\n", lane_count);
	}
}

#if OS == .WINDOWS {
    kernel32 :: #system_library "kernel32";
    SwitchToThread :: () -> s32 #foreign kernel32;

	InitializeCriticalSection :: (lpCriticalSection: *CRITICAL_SECTION) #foreign kernel32;
	EnterCriticalSection :: (lpCriticalSection: *CRITICAL_SECTION) #foreign kernel32;
	LeaveCriticalSection :: (lpCriticalSection: *CRITICAL_SECTION) #foreign kernel32;
	InitializeConditionVariable :: (ConditionVariable: *CONDITION_VARIABLE) #foreign kernel32;
	SleepConditionVariableCS :: (ConditionVariable: *CONDITION_VARIABLE, CriticalSection: *CRITICAL_SECTION, dwMilliseconds: u32) -> s32 #foreign kernel32;
	WakeAllConditionVariable :: (ConditionVariable: *CONDITION_VARIABLE) #foreign kernel32;

	CRITICAL_SECTION :: struct { _: [40]u8; }  // Opaque, 40 bytes on x64
	CONDITION_VARIABLE :: struct { ptr: *void; }
	INFINITE :: 0xFFFFFFFF;
}
// TODO: we have meshes, do lights
barrier_wait :: (barrier: *Lane_Barrier) {
    EnterCriticalSection(*barrier.lock);
    
    gen := barrier.generation;
    barrier.count += 1;
    
    if barrier.count == barrier.total {
        barrier.count = 0;
        barrier.generation += 1;
        WakeAllConditionVariable(*barrier.cond);
    } else {
        while barrier.generation == gen {
            SleepConditionVariableCS(*barrier.cond, *barrier.lock, INFINITE);
        }
    }
    
    LeaveCriticalSection(*barrier.lock);
}

thread_entry :: (thread: *Thread) -> s64{
	lane_system := *GAME_INSTANCE.lane_system;
	context.lane_count = lane_system.lane_count;
	context.lane_barrier = *lane_system.barrier;
	context.lane_shared_buffer = *lane_system.shared_buffer;

	game_loop();
	
	return 0;
}

lane_range :: (num: u32) -> u32, u32 {
    lane_count: u32 = context.lane_count;
    thread_idx: u32 = context.thread_index;

    per_lane := num / lane_count;
    rest := num % lane_count;
    
    has_leftover := thread_idx < rest;
    leftovers_before: u32;
    if has_leftover {
        leftovers_before = thread_idx;
    } else {
        leftovers_before = rest;
    }
    
    start : u32 = thread_idx * per_lane + leftovers_before;
    end : u32 = start + per_lane + xx,no_check(ifx has_leftover then 0 else -1);
    
    return start, end;
}