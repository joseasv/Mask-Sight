package game

import rl "vendor:raylib"

story_page: int = 0

state_story_on_enter :: proc() {
	story_page = 0
}

state_story_update :: proc() {
	if rl.IsKeyPressed(.ENTER) {
		// advance; single page -> go to Play
		g.state_requested = int(GameState.Play)
	}
	if rl.IsKeyPressed(.ESCAPE) {
		g.state_requested = int(GameState.Title)
	}
}

state_story_draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.SKYBLUE)

	// placeholder for illustration
	rl.DrawRectangle(160, 40, 480, 320, rl.BLACK)
	rl.DrawText("Historia: (press ENTER to jugar)", 180, 360, 14, rl.WHITE)

	// text window
	rl.DrawRectangle(80, 380, 560, 120, rl.BLACK)
	rl.DrawText("Un encuentro misterioso...\n(La historia va aqui)", 100, 400, 14, rl.WHITE)

	rl.EndDrawing()
}
