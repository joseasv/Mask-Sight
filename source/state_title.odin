package game

//import "core:fmt"
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
		g.state_requested = int(GameState.Play)
	}
	if rl.IsKeyPressed(.ESCAPE) {
		g.run = false
	}
}

state_title_draw :: proc() {
	w := f32(rl.GetScreenWidth())
	h := f32(rl.GetScreenHeight())

	rl.BeginDrawing()
	rl.ClearBackground(rl.DARKGRAY)

	rl.DrawTexture(
		g.titulo,
		i32(w / 2) - i32(g.titulo.width / 2),
		i32(h / 3) - i32(g.titulo.height / 2),
		rl.WHITE,
	)

	texto: cstring = "Presiona ENTER para iniciar"
	longitud := rl.MeasureText(texto, 32)
	rl.DrawText(
		"Presiona ENTER para iniciar",
		i32(w / 2) - longitud / 2,
		i32(h / 3) * 2,
		32,
		rl.RAYWHITE,
	)

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

