package game

import "core:math/rand"
import rl "vendor:raylib"

Collectible :: struct {
	pos:       rl.Vector2,
	aabb:      rl.Rectangle,
	collected: bool,
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

	tamCelda := f32(128 * 2)
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
