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

import rl "vendor:raylib"

Rect :: rl.Rectangle

PIXEL_WINDOW_HEIGHT :: 180


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
	shader_pared:          rl.Shader,
	loc_player_pos:        i32,
	loc_radius:            i32,
	loc_screen_height:     i32,
}

g: ^Game_Memory


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

start_new_maze :: proc(newRows: int, newCols: int) {
	paredes, vEnt, vSal := crearLaberinto(newRows, newCols, g.current_level)
	fmt.println("el vertice de entrada es", vEnt, "y el de salida es", vSal)
	fmt.println("filas y columnas para el nuevo laberinto", newRows, newCols)
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
	tamCelda := f32(128 * 2)
	col := vEnt % newCols
	row := vEnt / newCols
	fmt.println("start_new_maze col row para pos jugador", col, row)
	g.personaje.pos = rl.Vector2 {
		f32(col) * tamCelda + tamCelda / 2,
		f32(row) * tamCelda + tamCelda / 2,
	}

	g.personaje.aabb.width = g.personaje.size.x
	g.personaje.aabb.height = g.personaje.size.y
	g.personaje.aabb.x = g.personaje.pos.x
	g.personaje.aabb.y = g.personaje.pos.y

	g.personaje.hurtAABB.width = g.personaje.size.x
	g.personaje.hurtAABB.height = g.personaje.size.y
	g.personaje.hurtAABB.x = g.personaje.pos.x - g.personaje.hurtAABB.width / 3
	g.personaje.hurtAABB.y = g.personaje.pos.y - g.personaje.hurtAABB.height / 3


	fmt.println("start_new_maze player aabb", g.personaje.aabb)
	fmt.println("pos inicial para el jugador en start_new_maze", g.personaje.pos)
	// generar nuevos collectibles
	generate_collectibles(newRows, newCols)
	// generar nuevos enemigos
	generate_enemies(newRows, newCols)
}

ui_camera :: proc() -> rl.Camera2D {
	return {zoom = f32(rl.GetScreenHeight()) / PIXEL_WINDOW_HEIGHT}
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
	fmt.println("pos inicial para el jugador en game_init", pos)

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
		shader_pared         = rl.LoadShader(nil, "assets/wall_mask.fs"), // nil porque usamos el vertex shader por defecto
	}

	g.loc_player_pos = rl.GetShaderLocation(g.shader_pared, "playerPos")
	g.loc_radius = rl.GetShaderLocation(g.shader_pared, "radius")
	g.loc_screen_height = rl.GetShaderLocation(g.shader_pared, "screenHeight")

	radio := f32(60.0)
	rl.SetShaderValue(g.shader_pared, g.loc_radius, &radio, .FLOAT)

	pNuevo := Personaje {
		pos           = pos,
		hp            = 3,
		runAnim       = animation_create(.Correr),
		runAttackAnim = animation_create(.Correr_Ataque),
		idleAnim      = animation_create(.Idle),
		victoryAnim   = animation_create(.Victory),
		tint          = rl.YELLOW,
	}

	pNuevo.size = {128, 128} // disponible despues de cargar las animaciones
	pNuevo.aabb = rl.Rectangle {
		x      = pNuevo.pos.x,
		y      = pNuevo.pos.y,
		width  = pNuevo.size.x,
		height = pNuevo.size.y,
	}
	pNuevo.hurtAABB = rl.Rectangle {
		x      = pNuevo.pos.x,
		y      = pNuevo.pos.y,
		width  = pNuevo.size.x / 3,
		height = pNuevo.size.y / 3,
	}

	g.personaje = pNuevo


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
