package game

import "core:fmt"
import rl "vendor:raylib"

credits_visible: bool = false

state_title_on_enter :: proc() {
	// default difficulty
	if g.selected_difficulty == 0 {g.selected_difficulty = 1}
}

state_title_update :: proc() {
	if rl.IsKeyPressed(.ONE) {g.selected_difficulty = 1}
	if rl.IsKeyPressed(.TWO) {g.selected_difficulty = 2}
	if rl.IsKeyPressed(.THREE) {g.selected_difficulty = 3}
	if rl.IsKeyPressed(.C) {credits_visible = !credits_visible}
	if rl.IsKeyPressed(.ENTER) {
		g.state_requested = int(GameState.Select)
	}
	if rl.IsKeyPressed(.ESCAPE) {
		g.run = false
	}
}

state_title_draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.DARKGRAY)

	rl.DrawText("MASK-SIGHT", 120, 40, 48, rl.WHITE)
	rl.DrawText(
		fmt.ctprintf("Dificultad: %v (1-3)", g.selected_difficulty),
		120,
		120,
		20,
		rl.WHITE,
	)
	rl.DrawText("Presiona ENTER para seleccionar personaje", 120, 160, 14, rl.RAYWHITE)
	rl.DrawText("Presiona C para créditos", 120, 180, 12, rl.LIGHTGRAY)

	if credits_visible {
		rl.DrawRectangle(80, 220, 560, 160, rl.BLACK)
		rl.DrawText(
			"Créditos:\n- Juego creado en Odin\n- Assets de ejemplo",
			100,
			240,
			14,
			rl.WHITE,
		)
	}

	rl.EndDrawing()
}
