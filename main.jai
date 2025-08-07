rl	:: #import "raylib";
#import "Basic";
#import "Math";

main :: () {
	size_x : s32 = 1920;
	size_y : s32 = 1080;
	rl.InitWindow(size_x, size_y, "ZEngine");
	//defer rl.CloseWindow();

	world := create_zworld();

	init_archetype(world, Archetype_Ship); // Manual for now
	create_entity(world, Archetype_Ship);
	entity := world.world_entities[0];
	position := get_entity_component(world, entity, Position).pos;


	print("Entity Scale: %\n", position);

	Camera : rl.Camera3D;
	Camera.position = Vector3.{ 0, 10, 10 };
	Camera.target = Vector3.{ 0,0,0 };
	Camera.up = Vector3.{ 0, 1, 0 };
	Camera.fovy = 45;
	Camera.projection = .CAMERA_PERSPECTIVE;

	x : Bit_Field(5);
	
	rl.DisableCursor();
	rl.SetTargetFPS(240);
    while !rl.WindowShouldClose() {

		rl.UpdateCamera(*Camera, .CAMERA_FREE);
        rl.BeginDrawing();
		defer rl.EndDrawing();
		{
			rl.ClearBackground(rl.GRAY);

			rl.BeginMode3D(*Camera);

			rl.DrawGrid(10, 1);
		
			rl.EndMode3D();
		}
		rl.DrawFPS(10, 10);
    }
}

