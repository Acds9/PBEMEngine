World_Type :: enum_flags u8 {
	MAIN_MENU;
	REPLAY;
	SIMULATION;
}

Game_World :: struct {
	name	: string;
	type	: World_Type;
	world	: ZWorld;
	scene	: ZScene;
}