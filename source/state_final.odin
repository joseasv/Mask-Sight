package game

import rl "vendor:raylib"

state_final_on_enter :: proc() {
	// nothing for now
}

state_final_update :: proc() {
	if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.SPACE) || rl.IsKeyPressed(.ESCAPE) {
		g.state_requested = int(GameState.Title)
	}
}

state_final_draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	// show a full-screen reveal image if available; fallback to player texture
	w := rl.GetScreenWidth()
	h := rl.GetScreenHeight()
	// draw texture centered and scaled to cover
	if g.player_texture.id != 0 {
		rl.DrawTexturePro(
			g.player_texture,
			rl.Rectangle{0, 0, f32(g.player_texture.width), f32(g.player_texture.height)},
			rl.Rectangle{0, 0, f32(w), f32(h)},
			rl.Vector2{0, 0},
			0,
			rl.WHITE,
		)
	}

	rl.EndDrawing()
}
