package game

import "core:math/rand"
import rl "vendor:raylib"

color_lerp :: proc(a, b: rl.Color, t: f32) -> rl.Color {
	tt := t
	if tt < 0.0 {tt = 0.0}
	if tt > 1.0 {tt = 1.0}
	r := u8(f32(a.r) + (f32(b.r) - f32(a.r)) * tt)
	g_ := u8(f32(a.g) + (f32(b.g) - f32(a.g)) * tt)
	b_ := u8(f32(a.b) + (f32(b.b) - f32(a.b)) * tt)
	a_ := u8(f32(a.a) + (f32(b.a) - f32(a.a)) * tt)
	return rl.Color{r, g_, b_, a_}
}

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
	dt := rl.GetFrameTime()
	// detectar colisión con pared de salida para iniciar fade (antes de resolver)
	if g.fade_phase == 0 {
		updatePersonaje(&g.personaje, dt)
		update_enemies(dt)

		for p in g.laberintoActual {
			if p.tipo == 2 {
				if rl.CheckCollisionRecs(g.personaje.aabb, p.aabb) {
					g.fade_phase = 1 // start fade out
					g.fade_timer = 0.0
					g.reached_exit = true

					break
				}
			}
		}

		// resolver colisiones contra el laberinto (slide)
		resolverColisionesJugador()

		// recoger collectibles: si el jugador colisiona con uno, se activa la
		// revelación por 3s (acumulable)
		for i in 0 ..< len(g.collectibles) {
			c := &g.collectibles[i]
			if !c.collected {
				if rl.CheckCollisionRecs(g.personaje.aabb, c.aabb) {
					c.collected = true
					g.internal_walls_timer += 3.0
					g.show_internal_walls = true
					g.personaje.tint = rl.YELLOW
				}
			}
		}


		if g.show_internal_walls {
			g.internal_walls_timer -= dt
			if g.internal_walls_timer <= 0.0 {
				g.show_internal_walls = false
				g.internal_walls_timer = 0.0
			}
		}

		// Interpolate player tint from yellow -> white over the 3s timer
		if g.internal_walls_timer > 0.0 {
			progress := 1.0 - (g.internal_walls_timer / 3.0)
			if progress < 0.0 {progress = 0.0}
			if progress > 1.0 {progress = 1.0}
			g.personaje.tint = color_lerp(rl.YELLOW, rl.WHITE, progress)
		} else {
			g.personaje.tint = rl.WHITE
		}

		// update shake / stun timers
		if g.shake_timer > 0.0 {
			g.shake_timer -= dt
			if g.shake_timer < 0.0 {g.shake_timer = 0.0}
		}
		if g.stun_timer > 0.0 {
			g.stun_timer -= dt
			if g.stun_timer < 0.0 {g.stun_timer = 0.0}
		}

		// invincibility timer (player recently hit)
		if g.inv_timer > 0.0 {
			g.inv_timer -= dt
			if g.inv_timer < 0.0 {g.inv_timer = 0.0}
		}

		// update enemy flash/dead timers and respawn dead enemies at border far from player
		tamCelda := f32(40)
		for i in 0 ..< len(g.enemies) {
			e := &g.enemies[i]
			if e.flash_timer > 0.0 {
				e.flash_timer -= dt
				if e.flash_timer < 0.0 {e.flash_timer = 0.0}
			}
			if e.dead_timer > 0.0 {
				e.dead_timer -= dt
				if e.dead_timer <= 0.0 {
					// respawn enemy at random border cell far from player
					rows := g.maze_rows
					cols := g.maze_cols
					placed := false
					for _ in 0 ..< 20 {
						side := int(rl.GetRandomValue(i32(0), i32(3)))
						rr := 0
						cc := 0
						if side == 0 {
							// top row (r=0), random col
							rr = 0
							cc = int(rl.GetRandomValue(i32(0), i32(cols - 1)))
						} else if side == 1 {
							// bottom row
							rr = rows - 1
							cc = int(rl.GetRandomValue(i32(0), i32(cols - 1)))
						} else if side == 2 {
							// left col
							cc = 0
							rr = int(rl.GetRandomValue(i32(0), i32(rows - 1)))
						} else {
							// right col
							cc = cols - 1
							rr = int(rl.GetRandomValue(i32(0), i32(rows - 1)))
						}
						px := f32(cc) * tamCelda + tamCelda / 2
						py := f32(rr) * tamCelda + tamCelda / 2
						dx := px - g.personaje.pos.x
						dy := py - g.personaje.pos.y
						if dx * dx + dy * dy >= (tamCelda * tamCelda * 9) {
							// accept
							e.pos = rl.Vector2{px, py}
							size := f32(12)
							e.aabb = rl.Rectangle{px - size / 2, py - size / 2, size, size}
							e.hp = 1
							e.flash_timer = 0.0
							e.dead_timer = 0.0
							e.alive = true
							placed = true
							break
						}
					}
					if !placed {
						// fallback: place at opposite of player
						px := g.personaje.pos.x + tamCelda * 4
						py := g.personaje.pos.y + tamCelda * 4
						e.pos = rl.Vector2{px, py}
						size := f32(12)
						e.aabb = rl.Rectangle{px - size / 2, py - size / 2, size, size}
						e.hp = 1
						e.flash_timer = 0.0
						e.dead_timer = 0.0
						e.alive = true
					}
				}
			}
		}
	}


	// handle fading sequence
	if g.fade_phase != 0 {
		g.fade_timer += dt
		fade_duration := f32(2.0)
		if g.fade_phase == 1 {
			if g.fade_timer >= fade_duration {
				if g.reached_exit {
					// level progression: up to 4 levels
					if g.current_level < 4 {
						g.current_level += 1
						// make next maze larger
						newRows := g.maze_rows
						newCols := g.maze_cols
						if rand.float32() < 0.5 {
							newRows = newRows + 1
						} else {
							newCols = newCols + 1
						}

						start_new_maze(newRows, newCols)
						// switch to fade in
						g.fade_phase = 2
						g.fade_timer = 0.0
						g.reached_exit = false
					} else {
						// final level completed -> go to Final state
						g.state_requested = int(GameState.Final)
						g.reached_exit = false
						// reset fade
						g.fade_phase = 0
						g.fade_timer = 0.0
					}
				}


			}
		} else if g.fade_phase == 2 {
			if g.fade_timer >= fade_duration {
				g.fade_phase = 0
				g.fade_timer = 0.0
			}
		}
	}

	if rl.IsKeyPressed(.ESCAPE) {
		g.run = false
	}


}

state_play_draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	rl.BeginMode2D(game_camera())
	// dibujar la textura centrada en `g.player_pos` (parpadeo si invencible)
	visible := true
	if g.inv_timer > 0.0 {
		// blink frequency ~5 Hz
		if (i32(rl.GetTime() * 5.0) % 2) == 0 {
			visible = false
		}
	}

	dibujarLaberinto()
	drawPersonaje(g.personaje, visible)


	// dibujar collectibles
	for c in g.collectibles {
		if !c.collected {
			size := f32(12)
			rl.DrawRectangleV({c.pos.x - size / 2, c.pos.y - size / 2}, {size, size}, rl.YELLOW)
		}
	}

	draw_enemies()

	rl.EndMode2D()

	rl.BeginMode2D(ui_camera())

	// Draw HP in top-right corner (UI camera coordinates)
	ui_w := PIXEL_WINDOW_HEIGHT * f32(rl.GetScreenWidth()) / f32(rl.GetScreenHeight())
	label_x := i32(ui_w) - 120
	rl.DrawText("HP", label_x, 5, 12, rl.WHITE)
	boxSize := i32(10)
	gap := i32(4)
	boxStartX := i32(ui_w) - 80
	for k in 0 ..< 3 {
		bx := boxStartX + i32(k) * (boxSize + gap)
		if k < g.personaje.hp {
			rl.DrawRectangle(bx, 6, boxSize, boxSize, rl.RED)
		} else {
			rl.DrawRectangle(bx, 6, boxSize, boxSize, rl.DARKGRAY)
		}
	}

	rl.EndMode2D()

	// draw full-screen fade overlay when transitioning
	if g.fade_phase != 0 {
		fade_duration := f32(2.0)
		prog := g.fade_timer / fade_duration
		if prog < 0.0 {prog = 0.0}
		if prog > 1.0 {prog = 1.0}
		alpha := u8(0)
		if g.fade_phase == 1 {
			// fade out: alpha grows
			alpha = u8(prog * f32(255.0))
		} else {
			// fade in: alpha decreases
			alpha = u8((1.0 - prog) * f32(255.0))
		}
		overlay := rl.Color{u8(0), u8(0), u8(0), alpha}
		rl.DrawRectangle(0, 0, rl.GetScreenWidth(), rl.GetScreenHeight(), overlay)
	}

	rl.EndDrawing()
}
