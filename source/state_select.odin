package game

import rl "vendor:raylib"

state_select_on_enter :: proc() {
	if g.selected_character < 0 || g.selected_character > 1 {g.selected_character = 0}
}

state_select_update :: proc() {
	if rl.IsKeyPressed(.LEFT) ||
	   rl.IsKeyPressed(.A) {if g.selected_character > 0 {g.selected_character -= 1}}
	if rl.IsKeyPressed(.RIGHT) ||
	   rl.IsKeyPressed(.D) {if g.selected_character < 1 {g.selected_character += 1}}
	if rl.IsKeyPressed(.ENTER) {
		g.state_requested = int(GameState.Story)
	}
	if rl.IsKeyPressed(.ESCAPE) {
		g.state_requested = int(GameState.Title)
	}
}

state_select_draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.DARKBLUE)

	rl.DrawText("Selecciona Personaje", 120, 40, 36, rl.WHITE)
	// draw two placeholders
	rl.DrawRectangle(160, 120, 160, 160, rl.LIGHTGRAY)
	rl.DrawRectangle(360, 120, 160, 160, rl.LIGHTGRAY)

	// highlight selected
	if g.selected_character == 0 {
		rl.DrawRectangleLines(160, 120, 160, 160, rl.YELLOW)
	} else {
		rl.DrawRectangleLines(360, 120, 160, 160, rl.YELLOW)
	}

	rl.DrawText("Presiona ENTER para continuar", 120, 300, 14, rl.WHITE)
	rl.EndDrawing()
}
