package game

import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

Enemy :: struct {
	pos:         rl.Vector2,
	aabb:        rl.Rectangle,
	speed:       f32,
	hp:          int,
	flash_timer: f32,
	dead_timer:  f32,
	alive:       bool,
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

update_enemies :: proc(dt: f32) {

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
					//fmt.println(fmt.ctprintf("enemy hit idx=%v hp=%v", i, e.hp))
					if e.hp <= 0 {
						e.dead_timer = f32(0.5)
						// keep alive until dead_timer expires to allow fade
					}
				}
			}
		}
	}

	// simple lose detection: if any alive enemy touches player while
	// internal walls are hidden, consider it a loss and go back to title
	if !g.show_internal_walls && g.fade_phase == 0 {
		for i in 0 ..< len(g.enemies) {
			e := &g.enemies[i]
			if e.alive {
				if rl.CheckCollisionRecs(g.personaje.aabb, e.aabb) {
					// only apply damage if not currently invincible
					if g.inv_timer <= 0.0 {
						// player takes damage
						g.personaje.hp -= 1
						// set invincibility (3s)
						g.inv_timer = f32(3.0)
						// reset the enemy similar to when it's killed: set hp to 0 and dead_timer so it fades and will respawn
						e.hp = 0
						e.dead_timer = f32(0.5)
						e.flash_timer = 0.0

						if g.personaje.hp <= 0 {
							g.state_requested = int(GameState.Title)
							return
						}
					}
				}
			}
		}
	}
}

draw_enemies :: proc() {
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
}
