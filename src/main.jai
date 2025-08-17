rl	:: #import "raylib";
#import "Basic";
#import "Random";
#import "Math";

main :: () {
	size_x : s32 = 1920;
	size_y : s32 = 1080;
	rl.InitWindow(size_x, size_y, "ZEngine");
	//defer rl.CloseWindow();

	world := create_zworld();

	init_archetype(world, Archetype_Ship); // Manual for now
	
	register_Observer_Ship_Spawn(world);
	
	create_entity_batch(world, Archetype_Ship, 16);
	
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
			tick_world(world, 0);

			rl.DrawGrid(10, 1);
			rand := random_get_within_range(-5,5);
			execute_Query_Position_Randomizer(world, #code {
				/*for *position_array {
						it.pos = VECTOR_ONE * rand;
					}*/
			});
			rl.EndMode3D();
		}
		rl.DrawFPS(10, 10);
    }
}

