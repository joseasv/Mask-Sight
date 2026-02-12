/*
This file is the starting point of your game.

Some important procedures are:
- game_init_window: Opens the window
- game_init: Sets up the game state
- game_update: Run once per frame
- game_should_close: For stopping your game when close button is pressed
- game_shutdown: Shuts down game and frees memory
- game_shutdown_window: Closes window

The procs above are used regardless if you compile using the `build_release`
script or the `build_hot_reload` script. However, in the hot reload case, the
contents of this file is compiled as part of `build/hot_reload/game.dll` (or
.dylib/.so on mac/linux). In the hot reload cases some other procedures are
also used in order to facilitate the hot reload functionality:

- game_memory: Run just before a hot reload. That way game_hot_reload.exe has a
	pointer to the game's memory that it can hand to the new game DLL.
- game_hot_reloaded: Run after a hot reload so that the `g` global
	variable can be set to whatever pointer it was in the old DLL.

NOTE: When compiled as part of `build_release`, `build_debug` or `build_web`
then this whole package is just treated as a normal Odin package. No DLL is
created.
*/

package game

import "core:fmt"
import "core:math"

import "core:math/rand"
import rl "vendor:raylib"

Rect :: rl.Rectangle

PIXEL_WINDOW_HEIGHT :: 180

GameState :: enum {
	Title,
	Select,
	Story,
	Play,
	Final,
}

Game_Memory :: struct {
	some_number:           int,
	run:                   bool,
	laberintoActual:       [dynamic]Pared,
	pared:                 []Pared,
	vEntrada:              int,
	vSalida:               int,
	show_internal_walls:   bool,
	internal_walls_timer:  f32,

	// maze dimensions used to spawn collectibles
	spriteParedHorizontal: rl.Texture2D,
	spriteParedVertical:   rl.Texture2D,
	maze_rows:             int,
	maze_cols:             int,
	collectibles:          [dynamic]Collectible,
	// fade state: 0 = none, 1 = fading out, 2 = fading in
	fade_phase:            int,
	fade_timer:            f32,
	// screen shake / stun
	shake_timer:           f32,
	stun_timer:            f32,
	enemies:               [dynamic]Enemy,
	// state system
	state_requested:       int, // -1 = none, otherwise GameState
	selected_difficulty:   int,
	selected_character:    int,
	reached_exit:          bool,
	inv_timer:             f32,
	current_level:         int,
	atlas:                 rl.Texture,
	titulo:                rl.Texture,
	personaje:             Personaje,
}

g: ^Game_Memory

Collectible :: struct {
	pos:       rl.Vector2,
	aabb:      rl.Rectangle,
	collected: bool,
}

Enemy :: struct {
	pos:         rl.Vector2,
	aabb:        rl.Rectangle,
	speed:       f32,
	hp:          int,
	flash_timer: f32,
	dead_timer:  f32,
	alive:       bool,
}

game_camera :: proc() -> rl.Camera2D {
	w := f32(rl.GetScreenWidth())
	h := f32(rl.GetScreenHeight())

	// apply screen shake offset if active
	target := g.personaje.pos
	if g.shake_timer > 0.0 {
		// magnitude in pixels, decay with time
		maxMag := f32(8)
		mag := maxMag * (g.shake_timer / f32(1.0))
		rx := f32(rl.GetRandomValue(i32(-mag), i32(mag)))
		ry := f32(rl.GetRandomValue(i32(-mag), i32(mag)))
		target = rl.Vector2{g.personaje.pos.x + rx, g.personaje.pos.y + ry}
	}

	return {zoom = 1, target = target, offset = {w / 2, h / 2}}
}

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

// Generate collectibles for the current maze size; excludes the current entry/exit
generate_collectibles :: proc(rows: int, cols: int) {
	g.collectibles = make([dynamic]Collectible, 0)

	numCollectibles := rl.GetRandomValue(i32(rows), i32(cols))

	// candidatos de celdas (excluir entrada/salida)
	candidates := make([dynamic]int, 0)
	for r in 0 ..< rows {
		for c in 0 ..< cols {
			v := r * cols + c
			if v == g.vEntrada || v == g.vSalida {
				continue
			}
			append(&candidates, v)
		}
	}
	rand.shuffle(candidates[:])

	tamCelda := f32(150)
	for i in 0 ..< numCollectibles {
		v := candidates[i]
		cc := v % cols
		rr := v / cols
		p := rl.Vector2{f32(cc) * tamCelda + tamCelda / 2, f32(rr) * tamCelda + tamCelda / 2}
		size := f32(12)
		aabb := rl.Rectangle{p.x - size / 2, p.y - size / 2, size, size}
		append(&g.collectibles, Collectible{pos = p, aabb = aabb, collected = false})
	}
}

// Generate enemies (ghosts) placed on wall centers, far from entry and exit
generate_enemies :: proc(rows: int, cols: int) {
	g.enemies = make([dynamic]Enemy, 0)
	tamCelda := f32(40)

	// collect candidate wall centers
	candidates := make([dynamic]rl.Vector2, 0)
	for i in 0 ..< len(g.laberintoActual) {
		p := g.laberintoActual[i]
		// use wall center
		cx := p.aabb.x + p.aabb.width / 2
		cy := p.aabb.y + p.aabb.height / 2
		// distance from entry and exit
		entry_dx := cx - (f32(g.vEntrada % cols) * tamCelda + tamCelda / 2)
		entry_dy := cy - (f32(g.vEntrada / cols) * tamCelda + tamCelda / 2)
		exit_dx := cx - (f32(g.vSalida % cols) * tamCelda + tamCelda / 2)
		exit_dy := cy - (f32(g.vSalida / cols) * tamCelda + tamCelda / 2)
		if entry_dx * entry_dx + entry_dy * entry_dy < (tamCelda * tamCelda * 4) {continue}
		if exit_dx * exit_dx + exit_dy * exit_dy < (tamCelda * tamCelda * 4) {continue}
		append(&candidates, rl.Vector2{cx, cy})
	}

	if len(candidates) == 0 {return}

	// number of enemies: random between min(rows,cols) and max(rows,cols)
	minVal := 2
	maxVal := 4

	num := rl.GetRandomValue(i32(minVal), i32(maxVal))
	if num > i32(len(candidates)) {num = i32(len(candidates))}

	rand.shuffle(candidates[:])
	// speed scales with maze size (rows+cols)
	baseSpeed := f32(20.0)
	speedFactor := f32(rows + cols) / 10.0

	for i in 0 ..< num {
		c := candidates[i]
		size := f32(12)
		aabb := rl.Rectangle{c.x - size / 2, c.y - size / 2, size, size}
		sp := baseSpeed * speedFactor
		append(
			&g.enemies,
			Enemy {
				pos = c,
				aabb = aabb,
				speed = sp,
				hp = 1,
				flash_timer = 0.0,
				dead_timer = 0.0,
				alive = true,
			},
		)
	}
}

start_new_maze :: proc(newRows: int, newCols: int) {
	paredes, vEnt, vSal := crearLaberinto(newRows, newCols, g.current_level)
	// start each new maze with the internal walls revealed for 3s
	g.internal_walls_timer = f32(3.0)
	g.show_internal_walls = true
	g.personaje.tint = rl.YELLOW
	g.laberintoActual = paredes
	g.maze_rows = newRows
	g.maze_cols = newCols
	g.vEntrada = vEnt
	g.vSalida = vSal

	// reset player HP at level start
	g.personaje.hp = 3

	// colocar jugador en la celda de entrada
	tamCelda := f32(40)
	col := vEnt % newCols
	row := vEnt / newCols
	g.personaje.pos = rl.Vector2 {
		f32(col) * tamCelda + tamCelda / 2,
		f32(row) * tamCelda + tamCelda / 2,
	}

	g.personaje.aabb.width = g.personaje.size.x
	g.personaje.aabb.height = g.personaje.size.y
	g.personaje.aabb.x = g.personaje.pos.x - g.personaje.aabb.width / 2
	g.personaje.aabb.y = g.personaje.pos.y - g.personaje.aabb.height / 2

	fmt.println("start_new_maze player aabb", g.personaje.aabb)
	// generar nuevos collectibles
	generate_collectibles(newRows, newCols)
	// generar nuevos enemigos
	generate_enemies(newRows, newCols)
}

ui_camera :: proc() -> rl.Camera2D {
	return {zoom = f32(rl.GetScreenHeight()) / PIXEL_WINDOW_HEIGHT}
}

update :: proc() {

	dt := rl.GetFrameTime()

	updatePersonaje(&g.personaje, dt)

	// move enemies when internal walls are hidden and not fading
	if !g.show_internal_walls && g.fade_phase == 0 {
		for i in 0 ..< len(g.enemies) {
			e := &g.enemies[i]
			if !e.alive {continue}
			// move towards player
			dx := g.personaje.pos.x - e.pos.x
			dy := g.personaje.pos.y - e.pos.y
			dist := math.sqrt(dx * dx + dy * dy)
			if dist > 0.1 {
				nx := dx / dist
				ny := dy / dist
				e.pos.x += nx * e.speed * dt
				e.pos.y += ny * e.speed * dt
				e.aabb.x = e.pos.x - e.aabb.width / 2
				e.aabb.y = e.pos.y - e.aabb.height / 2
			}
		}
	}

	// while internal walls are visible, allow player to damage enemies by touching them
	if g.show_internal_walls && g.fade_phase == 0 {
		for i in 0 ..< len(g.enemies) {
			e := &g.enemies[i]
			if !e.alive {continue}
			if rl.CheckCollisionRecs(g.personaje.aabb, e.aabb) {
				// only apply damage once per contact using flash_timer as cooldown
				if e.flash_timer <= 0.0 {
					e.hp -= 1
					e.flash_timer = f32(0.25)
					fmt.println(fmt.ctprintf("enemy hit idx=%v hp=%v", i, e.hp))
					if e.hp <= 0 {
						e.dead_timer = f32(0.5)
						// keep alive until dead_timer expires to allow fade
					}
				}
			}
		}
	}

	// detectar colisión con pared de salida para iniciar fade (antes de resolver)
	if g.fade_phase == 0 {
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
	}

	if (g.fade_phase == 0) {
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
						newRows := g.maze_rows + 2
						newCols := g.maze_cols + 2
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
				} else {
					// generate new maze with increased rows or cols by 2 (fallback path)

					newRows := g.maze_rows
					newCols := g.maze_cols
					if rl.GetRandomValue(0, 1) == 0 {
						newRows += 2
					} else {
						newCols += 2
					}
					start_new_maze(newRows, newCols)

					// switch to fade in
					g.fade_phase = 2
					g.fade_timer = 0.0
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

draw :: proc() {
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

	// dibujar enemigos (fantasmas)
	for i in 0 ..< len(g.enemies) {
		e := &g.enemies[i]
		if !e.alive && e.dead_timer <= 0.0 {continue}

		// base alpha: visible when internal walls shown, otherwise faint
		baseAlpha := f32(64)
		if g.show_internal_walls {
			baseAlpha = f32(255)
		}

		// if dead and fading, fade alpha by remaining dead_timer
		alphaF := baseAlpha
		if e.dead_timer > 0.0 {
			alphaF = (e.dead_timer / f32(0.5)) * f32(255)
		}

		alpha := u8(alphaF)

		// if flashing, draw bright (white) overlay
		if e.flash_timer > 0.0 {
			col := rl.Color{u8(255), u8(255), u8(255), alpha}
			rl.DrawRectangleV(
				{e.pos.x - e.aabb.width / 2, e.pos.y - e.aabb.height / 2},
				{e.aabb.width, e.aabb.height},
				col,
			)
		} else {
			col := rl.Color{u8(255), u8(0), u8(0), alpha}
			rl.DrawRectangleV(
				{e.pos.x - e.aabb.width / 2, e.pos.y - e.aabb.height / 2},
				{e.aabb.width, e.aabb.height},
				col,
			)
		}
	}


	rl.DrawRectangleLines(
		i32(g.personaje.aabb.x),
		i32(g.personaje.aabb.y),
		i32(g.personaje.aabb.width),
		i32(g.personaje.aabb.height),
		rl.GREEN,
	)

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

@(export)
game_update :: proc() {
	// Delegate update/draw to state machine
	state_machine_update()
	state_machine_draw()

	// Everything on tracking allocator is valid until end-of-frame.
	free_all(context.temp_allocator)
}

@(export)
game_init_window :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(1280, 720, "Odin + Raylib + Hot Reload template!")
	rl.SetWindowPosition(200, 200)
	rl.SetTargetFPS(500)
	rl.SetExitKey(nil)
}

@(export)
game_init :: proc() {
	g = new(Game_Memory)

	// crear el laberinto y obtener paredes + vértices de entrada/salida
	rows := 4
	cols := 6
	paredes, vEnt, vSal := crearLaberinto(rows, cols, 1)

	// calcular posición del jugador: centro de la celda de entrada
	tamCelda := f32(128 * 2)
	col := vEnt % cols
	row := vEnt / cols
	pos := rl.Vector2{f32(col) * tamCelda + tamCelda / 2, f32(row) * tamCelda + tamCelda / 2}

	g^ = Game_Memory {
		run                  = true,
		some_number          = 100,

		// You can put textures, sounds and music in the `assets` folder. Those
		// files will be part any release or web build.
		titulo               = rl.LoadTexture("assets/titulo.png"),
		atlas                = rl.LoadTexture("assets/atlas.png"),
		// reveal internal walls at level start for a short grace period
		show_internal_walls  = true,
		internal_walls_timer = f32(3.0),
		maze_rows            = rows,
		maze_cols            = cols,
		collectibles         = make([dynamic]Collectible, 0),
		inv_timer            = 0.0,
		current_level        = 1,
		fade_phase           = 0,
		fade_timer           = 0.0,
		laberintoActual      = paredes,
		vEntrada             = vEnt,
		vSalida              = vSal,
	}

	pNuevo := Personaje {
		pos           = pos,
		hp            = 3,
		runAnim       = animation_create(.Correr),
		runAttackAnim = animation_create(.Correr_Ataque),
		idleAnim      = animation_create(.Idle),
		victoryAnim   = animation_create(.Victory),
		tint          = rl.YELLOW,
	}

	pNuevo.size = atlas_animations[pNuevo.runAnim.atlas_anim].document_size.xy // disponible despues de cargar las animaciones
	pNuevo.aabb = rl.Rectangle {
		x      = pNuevo.pos.x - pNuevo.size.x / 2,
		y      = pNuevo.pos.y - pNuevo.size.y / 2,
		width  = pNuevo.size.x,
		height = pNuevo.size.y,
	}

	g.personaje = pNuevo

	fmt.println("game init")
	fmt.println(g.personaje.aabb)
	fmt.println(atlas_animations[pNuevo.runAnim.atlas_anim].document_size)
	fmt.println(g.personaje.size)
	fmt.println("game init")

	game_hot_reloaded(g)

	// generar collectibles y enemigos usando helpers
	generate_collectibles(rows, cols)
	generate_enemies(rows, cols)

	// initialize state machine
	state_machine_init()
}

@(export)
game_should_run :: proc() -> bool {
	when ODIN_OS != .JS {
		// Never run this proc in browser. It contains a 16 ms sleep on web!
		if rl.WindowShouldClose() {
			return false
		}
	}

	return g.run
}

@(export)
game_shutdown :: proc() {
	free(g)
}

@(export)
game_shutdown_window :: proc() {
	rl.CloseWindow()
}

@(export)
game_memory :: proc() -> rawptr {
	return g
}

@(export)
game_memory_size :: proc() -> int {
	return size_of(Game_Memory)
}

@(export)
game_hot_reloaded :: proc(mem: rawptr) {
	g = (^Game_Memory)(mem)

	// Here you can also set your own global variables. A good idea is to make
	// your global variables into pointers that point to something inside `g`.
}

@(export)
game_force_reload :: proc() -> bool {
	return rl.IsKeyPressed(.F5)
}

@(export)
game_force_restart :: proc() -> bool {
	return rl.IsKeyPressed(.F6)
}

// In a web build, this is called when browser changes size. Remove the
// `rl.SetWindowSize` call if you don't want a resizable game.
game_parent_window_size_changed :: proc(w, h: int) {
	rl.SetWindowSize(i32(w), i32(h))
}
