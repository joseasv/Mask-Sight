package game

import "core:math/linalg"
import rl "vendor:raylib"

EstadosPersonaje :: enum {
	Idle,
	Run,
	RunAttack,
	Victory,
}

Personaje :: struct {
	pos:           rl.Vector2,
	hp:            int,
	flip:          bool,
	size:          [2]f32,
	aabb:          rl.Rectangle,
	runAnim:       AnimationFromAtlas,
	runAttackAnim: AnimationFromAtlas,
	idleAnim:      AnimationFromAtlas,
	victoryAnim:   AnimationFromAtlas,
	tint:          rl.Color,
	state:         EstadosPersonaje,
}

updatePersonaje :: proc(p: ^Personaje, dt: f32) {
	// movement disabled while fading
	vel: f32 = 350
	input: rl.Vector2

	if g.fade_phase == 0 && g.stun_timer <= 0.0 {
		if rl.IsKeyDown(.UP) || rl.IsKeyDown(.W) {
			input.y -= 1
		}
		if rl.IsKeyDown(.DOWN) || rl.IsKeyDown(.S) {
			input.y += 1
		}
		if rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A) {
			g.personaje.flip = true
			input.x -= 1
		}
		if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D) {
			g.personaje.flip = false
			input.x += 1
		}
		input = linalg.normalize0(input)
		p.pos += input * dt * vel
	}

	if input.x == 0 && input.y == 0 {
		animation_update(&p.idleAnim, dt)
		p.state = .Idle
	} else {

		if g.internal_walls_timer > 0.0 {
			animation_update(&p.runAttackAnim, dt)
			p.state = .RunAttack
		} else {
			animation_update(&p.runAnim, dt)
			p.state = .Run
		}
	}

	p.aabb = rl.Rectangle {
		x      = p.pos.x - p.size.x / 2,
		y      = p.pos.y - p.size.y / 2,
		width  = p.size.x,
		height = p.size.y,
	}

	if g.reached_exit {
		p.state = .Victory
		animation_update(&p.victoryAnim, dt)
	}
}

drawPersonaje :: proc(p: Personaje, visible: bool) {
	currentAnim := p.idleAnim

	switch p.state {
	case .Idle:
		currentAnim = p.idleAnim
	case .Run:
		currentAnim = p.runAnim
	case .RunAttack:
		currentAnim = p.runAttackAnim
	case .Victory:
		currentAnim = p.victoryAnim
	}

	animation_atlas_draw(
		currentAnim,
		rl.Vector2{p.pos.x - p.size.x / 2, p.pos.y - p.size.y / 2},
		p.flip,
	)

	rl.DrawRectangleLines(
		i32(g.personaje.aabb.x),
		i32(g.personaje.aabb.y),
		i32(g.personaje.aabb.width),
		i32(g.personaje.aabb.height),
		rl.GREEN,
	)

}
