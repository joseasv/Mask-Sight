package game

import rl "vendor:raylib"

state_play_on_enter :: proc() {
	// start maze based on selected difficulty
	if g.selected_difficulty == 1 {
		start_new_maze(4, 6)
	} else if g.selected_difficulty == 2 {
		start_new_maze(6, 8)
	} else if g.selected_difficulty == 3 {
		start_new_maze(8, 10)
	} else {
		start_new_maze(4, 6)
	}
}

state_play_update :: proc() {
	// call existing game update logic
	update()

	// simple lose detection: if any alive enemy touches player while
	// internal walls are hidden, consider it a loss and go back to title
	if !g.show_internal_walls && g.fade_phase == 0 {
		for e in g.enemies {
			if e.alive {
				if rl.CheckCollisionRecs(g.player_aabb, e.aabb) {
					g.state_requested = int(GameState.Title)
					return
				}
			}
		}
	}
}

state_play_draw :: proc() {
	draw()
}
