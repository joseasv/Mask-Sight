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
import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"

PIXEL_WINDOW_HEIGHT :: 180

Game_Memory :: struct {
	player_pos:           rl.Vector2,
	player_texture:       rl.Texture,
	some_number:          int,
	run:                  bool,
	laberintoActual:      [dynamic]Pared,
	pared:                []Pared,
	vEntrada:             int,
	vSalida:              int,
	player_aabb:          rl.Rectangle,
	show_internal_walls:  bool,
	internal_walls_timer: f32,
	player_tint:          rl.Color,
	// maze dimensions used to spawn collectibles
	maze_rows:            int,
	maze_cols:            int,
	collectibles:         [dynamic]Collectible,
}

g: ^Game_Memory

Collectible :: struct {
	pos:       rl.Vector2,
	aabb:      rl.Rectangle,
	collected: bool,
}

game_camera :: proc() -> rl.Camera2D {
	w := f32(rl.GetScreenWidth())
	h := f32(rl.GetScreenHeight())

	return {zoom = h / PIXEL_WINDOW_HEIGHT, target = g.player_pos, offset = {w / 2, h / 2}}
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

ui_camera :: proc() -> rl.Camera2D {
	return {zoom = f32(rl.GetScreenHeight()) / PIXEL_WINDOW_HEIGHT}
}

update :: proc() {
	input: rl.Vector2

	if rl.IsKeyDown(.UP) || rl.IsKeyDown(.W) {
		input.y -= 1
	}
	if rl.IsKeyDown(.DOWN) || rl.IsKeyDown(.S) {
		input.y += 1
	}
	if rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A) {
		input.x -= 1
	}
	if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D) {
		input.x += 1
	}

	input = linalg.normalize0(input)
	g.player_pos += input * rl.GetFrameTime() * 100
	g.some_number += 1

	// actualizar AABB del jugador (rect centrado en player_pos)
	g.player_aabb = rl.Rectangle {
		x      = g.player_pos.x - f32(g.player_texture.width) / 2,
		y      = g.player_pos.y - f32(g.player_texture.height) / 2,
		width  = f32(g.player_texture.width),
		height = f32(g.player_texture.height),
	}

	// resolver colisiones contra el laberinto (slide)
	resolverColisionesJugador()

	// recoger collectibles: si el jugador colisiona con uno, se activa la
	// revelación por 3s (acumulable)
	for i in 0 ..< len(g.collectibles) {
		c := &g.collectibles[i]
		if !c.collected {
			if rl.CheckCollisionRecs(g.player_aabb, c.aabb) {
				c.collected = true
				g.internal_walls_timer += 3.0
				g.show_internal_walls = true
				g.player_tint = rl.YELLOW
			}
		}
	}

	if g.show_internal_walls {
		g.internal_walls_timer -= rl.GetFrameTime()
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
		g.player_tint = color_lerp(rl.YELLOW, rl.WHITE, progress)
	} else {
		g.player_tint = rl.WHITE
	}

	if rl.IsKeyPressed(.ESCAPE) {
		g.run = false
	}
}

draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	rl.BeginMode2D(game_camera())
	// dibujar la textura centrada en `g.player_pos`
	rl.DrawTextureEx(
		g.player_texture,
		rl.Vector2 {
			g.player_pos.x - f32(g.player_texture.width) / 2,
			g.player_pos.y - f32(g.player_texture.height) / 2,
		},
		0,
		1,
		g.player_tint,
	)
	rl.DrawRectangleV({20, 20}, {10, 10}, rl.RED)
	rl.DrawRectangleV({-30, -20}, {10, 10}, rl.GREEN)

	// dibujar collectibles
	for c in g.collectibles {
		if !c.collected {
			size := f32(12)
			rl.DrawRectangleV({c.pos.x - size / 2, c.pos.y - size / 2}, {size, size}, rl.YELLOW)
		}
	}
	dibujarLaberinto()
	rl.EndMode2D()

	rl.BeginMode2D(ui_camera())

	// NOTE: `fmt.ctprintf` uses the temp allocator. The temp allocator is
	// cleared at the end of the frame by the main application, meaning inside
	// `main_hot_reload.odin`, `main_release.odin` or `main_web_entry.odin`.
	rl.DrawText(
		fmt.ctprintf("some_number: %v\nplayer_pos: %v", g.some_number, g.player_pos),
		5,
		5,
		8,
		rl.WHITE,
	)

	rl.EndMode2D()

	rl.EndDrawing()
}

@(export)
game_update :: proc() {
	update()
	draw()

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
	tamCelda := f32(40)
	col := vEnt % cols
	row := vEnt / cols
	pos := rl.Vector2{f32(col) * tamCelda + tamCelda / 2, f32(row) * tamCelda + tamCelda / 2}

	g^ = Game_Memory {
		run                  = true,
		some_number          = 100,

		// You can put textures, sounds and music in the `assets` folder. Those
		// files will be part any release or web build.
		player_texture       = rl.LoadTexture("assets/round_cat.png"),
		player_pos           = pos,
		show_internal_walls  = false,
		internal_walls_timer = 0.0,
		player_tint          = rl.WHITE,
		maze_rows            = rows,
		maze_cols            = cols,
		collectibles         = make([dynamic]Collectible, 0),
		laberintoActual      = paredes,
		vEntrada             = vEnt,
		vSalida              = vSal,
	}

	// inicializar player_aabb ahora que la textura está cargada en g
	g.player_aabb = rl.Rectangle {
		x      = g.player_pos.x - f32(g.player_texture.width) / 2,
		y      = g.player_pos.y - f32(g.player_texture.height) / 2,
		width  = f32(g.player_texture.width),
		height = f32(g.player_texture.height),
	}

	game_hot_reloaded(g)

	// GENERAR collectibles aleatorios según tamaño del laberinto
	// cantidad aleatoria entre min(rows,cols) y max(rows,cols)
	minVal := rows / 2
	maxVal := cols / 2
	if minVal > maxVal {tmp := minVal; minVal = maxVal; maxVal = tmp}
	counts := make([dynamic]int, 0)
	for n in minVal ..< (maxVal + 1) {
		append(&counts, n)
	}
	rand.shuffle(counts[:])
	numCollectibles := counts[0]

	// generar lista de celdas candidatas (excluir entrada y salida)
	candidates := make([dynamic]int, 0)
	for r in 0 ..< rows {
		for c_ in 0 ..< cols {
			v := r * cols + c_
			if v == vEnt || v == vSal {continue}
			append(&candidates, v)
		}
	}
	rand.shuffle(candidates[:])
	// tomar los primeros numCollectibles candidatos
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
