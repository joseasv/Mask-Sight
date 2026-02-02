package game

import rl "vendor:raylib"

state_play_on_enter :: proc() {
	// start maze based on selected difficulty
	// reset level counter when entering Play

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
		for i in 0 ..< len(g.enemies) {
			e := &g.enemies[i]
			if e.alive {
				if rl.CheckCollisionRecs(g.player_aabb, e.aabb) {
					// only apply damage if not currently invincible
					if g.inv_timer <= 0.0 {
						// player takes damage
						g.player_hp -= 1
						// set invincibility (3s)
						g.inv_timer = f32(3.0)
						// reset the enemy similar to when it's killed: set hp to 0 and dead_timer so it fades and will respawn
						e.hp = 0
						e.dead_timer = f32(0.5)
						e.flash_timer = 0.0

						if g.player_hp <= 0 {
							g.state_requested = int(GameState.Title)
							return
						}
					}
				}
			}
		}
	}
}

state_play_draw :: proc() {
	draw()
}
