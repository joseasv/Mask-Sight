package game

import cq "core:container/queue"
import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:slice"
import rl "vendor:raylib"

Pared :: struct {
	inicio:    rl.Vector2,
	fin:       rl.Vector2,
	tipo:      int, // 0:borde, 1: interna, 2: salida
	color:     rl.Color,
	thickness: f32,
	aabb:      rl.Rectangle,
	revelada:  bool,
}

Laberinto :: struct {
	ady:          [][dynamic]int,
	predecesores: []int,
	distancias:   []int,
	filas:        int,
	columnas:     int,
}

crearLaberinto :: proc(filas: int, columnas: int, dificultad: int) -> ([dynamic]Pared, int, int) {
	laberinto := Laberinto {
		filas        = filas,
		columnas     = columnas,
		ady          = make([][dynamic]int, filas * columnas),
		predecesores = make([]int, filas * columnas),
		distancias   = make([]int, filas * columnas),
	}

	for filaActual in 0 ..< filas {
		for columnaActual in 0 ..< columnas {
			vertice := filaActual * columnas + columnaActual
			if columnaActual < columnas - 1 {
				append(&laberinto.ady[vertice], vertice + 1)
				append(&laberinto.ady[vertice + 1], vertice)
			}
			if filaActual < filas - 1 {
				append(&laberinto.ady[vertice], vertice + columnas)
				append(&laberinto.ady[vertice + columnas], vertice)
			}
		}
	}

	visitados := make([]bool, filas * columnas)

	// seleccionar un vértice de entrada aleatorio entre los vértices del borde
	border := make([dynamic]int, 0)
	for r in 0 ..< filas {
		for c in 0 ..< columnas {
			if r == 0 || r == filas - 1 || c == 0 || c == columnas - 1 {
				append(&border, r * columnas + c)
			}
		}
	}
	rand.shuffle(border[:])
	vEntrada := border[0]

	// inicializar distancias a -1
	slice.fill(laberinto.distancias, -1)

	visitados[vEntrada] = true
	laberinto.distancias[vEntrada] = 0

	if dificultad < 3 {
		// recorrido en anchura
		cola: cq.Queue(int)
		cq.init(&cola)
		cq.push(&cola, vEntrada)

		for cq.len(cola) > 0 {
			v := cq.pop_front(&cola)

			vecinosDesorden := laberinto.ady[v][:]
			rand.shuffle(vecinosDesorden)

			for w in vecinosDesorden {
				if !visitados[w] {
					visitados[w] = true
					laberinto.predecesores[w] = v
					laberinto.distancias[w] = laberinto.distancias[v] + 1
					cq.push(&cola, w)
				} else {
					if laberinto.predecesores[v] != w {
						// quitar la conexion en ambas direcciones entre v y w
						for vertice, i in laberinto.ady[w] {
							if vertice == v {
								unordered_remove(&laberinto.ady[w], i)

								break
							}
						}
						for vertice2, j in laberinto.ady[v] {
							if vertice2 == w {
								unordered_remove(&laberinto.ady[v], j)

								break
							}
						}
					}
				}
			}
		}

		fmt.println(laberinto)
	} else {
		// recorrido en profundidad (DFS iterativo)
		stack := make([dynamic]int, 0)
		append(&stack, vEntrada)
		visitados[vEntrada] = true
		laberinto.distancias[vEntrada] = 0

		for len(stack) > 0 {
			v := stack[len(stack) - 1]
			vecinosDesorden := laberinto.ady[v][:]
			rand.shuffle(vecinosDesorden)
			pushed := false
			for w in vecinosDesorden {
				if !visitados[w] {
					visitados[w] = true
					laberinto.predecesores[w] = v
					laberinto.distancias[w] = laberinto.distancias[v] + 1
					append(&stack, w)
					pushed = true
					break
				} else {
					if laberinto.predecesores[v] != w {
						// quitar la conexion en ambas direcciones entre v y w
						for vertice, i in laberinto.ady[w] {
							if vertice == v {
								unordered_remove(&laberinto.ady[w], i)
								break
							}
						}
						for vertice2, j in laberinto.ady[v] {
							if vertice2 == w {
								unordered_remove(&laberinto.ady[v], j)
								break
							}
						}
					}
				}
			}
			if !pushed {
				// backtrack
				unordered_remove(&stack, len(stack) - 1)
			}
		}
	}

	// Construir slice de paredes a partir del grafo resultante
	tamCelda := f32(40)
	paredes := make([dynamic]Pared, 0)

	// elegir vSalida: el vértice del borde más lejano desde vEntrada
	maxDist := -1
	candidatos := make([dynamic]int, 0)
	for _, v in border {
		d := laberinto.distancias[v]
		if d > maxDist {
			maxDist = d
			candidatos = make([dynamic]int, 0)
			append(&candidatos, v)
		} else if d == maxDist {
			append(&candidatos, v)
		}
	}
	rand.shuffle(candidatos[:])
	vSalida := candidatos[0]

	// elegir una pared exterior aleatoria para la entrada y la salida
	entradaWall := -1
	salidaWall := -1
	{
		row := vEntrada / columnas
		col := vEntrada % columnas
		opciones := make([dynamic]int, 0)
		if col == 0 {
			append(&opciones, 3) // izquierda
		}
		if col == columnas - 1 {
			append(&opciones, 0) // derecha
		}
		if row == 0 {
			append(&opciones, 2) // arriba
		}
		if row == filas - 1 {
			append(&opciones, 1) // abajo
		}
		if len(opciones) > 0 {
			rand.shuffle(opciones[:])
			entradaWall = opciones[0]
		}
	}
	{
		row := vSalida / columnas
		col := vSalida % columnas
		opciones := make([dynamic]int, 0)
		if col == 0 {
			append(&opciones, 3)
		}
		if col == columnas - 1 {
			append(&opciones, 0)
		}
		if row == 0 {
			append(&opciones, 2)
		}
		if row == filas - 1 {
			append(&opciones, 1)
		}
		if len(opciones) > 0 {
			rand.shuffle(opciones[:])
			salidaWall = opciones[0]
		}
	}

	for filaActual in 0 ..< filas {
		for columnaActual in 0 ..< columnas {
			vertice := filaActual * columnas + columnaActual
			x := f32(columnaActual) * tamCelda
			y := f32(filaActual) * tamCelda

			// pared derecha (vertical) — evitar duplicados usando solo la pared derecha
			if columnaActual == columnas - 1 ||
			   !slice.contains(laberinto.ady[vertice][:], vertice + 1) {
				inicio := rl.Vector2{x + tamCelda, y}
				fin := rl.Vector2{x + tamCelda, y + tamCelda}
				// entrada stays yellow; salida marked by tipo (2) but color kept yellow here
				//color := rl.YELLOW
				thickness := f32(8)
				// compute AABB for the wall (vertical)
				miny := inicio.y
				h := fin.y - inicio.y
				if inicio.y > fin.y {
					miny = fin.y
					h = inicio.y - fin.y
				}
				aabb := rl.Rectangle{inicio.x - thickness / 2, miny, thickness, h}
				// border check: right wall is border when columnaActual == columnas - 1
				is_border := columnaActual == columnas - 1
				tipo_val := 0
				if vertice == vSalida && salidaWall == 0 {
					tipo_val = 2
				} else if is_border {
					tipo_val = 0
				} else {
					tipo_val = 1
				}
				append(
					&paredes,
					Pared {
						inicio = inicio,
						fin = fin,
						tipo = tipo_val,
						color = rl.YELLOW,
						thickness = thickness,
						aabb = aabb,
						revelada = false,
					},
				)
			}

			// pared inferior (horizontal) — evitar duplicados usando solo la pared inferior
			if filaActual == filas - 1 ||
			   !slice.contains(laberinto.ady[vertice][:], vertice + columnas) {
				inicio := rl.Vector2{x, y + tamCelda}
				fin := rl.Vector2{x + tamCelda, y + tamCelda}
				// entrada always yellow; salida marked by tipo (2)
				//color := rl.YELLOW
				thickness := f32(8)
				minx := inicio.x
				w := fin.x - inicio.x
				if inicio.x > fin.x {
					minx = fin.x
					w = inicio.x - fin.x
				}
				aabb := rl.Rectangle{minx, inicio.y - thickness / 2, w, thickness}
				// bottom wall is border when filaActual == filas - 1
				is_border := filaActual == filas - 1
				tipo_val := 0
				if vertice == vSalida && salidaWall == 1 {
					tipo_val = 2
				} else if is_border {
					tipo_val = 0
				} else {
					tipo_val = 1
				}
				append(
					&paredes,
					Pared {
						inicio = inicio,
						fin = fin,
						tipo = tipo_val,
						color = rl.YELLOW,
						thickness = thickness,
						aabb = aabb,
						revelada = false,
					},
				)
			}

			// pared superior (solo en la primera fila)
			if filaActual == 0 {
				inicio := rl.Vector2{x, y}
				fin := rl.Vector2{x + tamCelda, y}
				// entrada always yellow; salida marked by tipo (2)
				//color := rl.YELLOW
				thickness := f32(8)
				minx := inicio.x
				w := fin.x - inicio.x
				if inicio.x > fin.x {
					minx = fin.x
					w = inicio.x - fin.x
				}
				aabb := rl.Rectangle{minx, inicio.y - thickness / 2, w, thickness}
				// top wall is border when filaActual == 0
				is_border := filaActual == 0
				tipo_val := 0
				if vertice == vSalida && salidaWall == 2 {
					tipo_val = 2
				} else if is_border {
					tipo_val = 0
				} else {
					tipo_val = 1
				}
				append(
					&paredes,
					Pared {
						inicio = inicio,
						fin = fin,
						tipo = tipo_val,
						color = rl.YELLOW,
						thickness = thickness,
						aabb = aabb,
						revelada = false,
					},
				)
			}

			// pared izquierda (solo en la primera columna)
			if columnaActual == 0 {
				inicio := rl.Vector2{x, y}
				fin := rl.Vector2{x, y + tamCelda}
				// entrada always yellow; salida marked by tipo (2)
				//color := rl.YELLOW
				thickness := f32(8)
				miny := inicio.y
				h := fin.y - inicio.y
				if inicio.y > fin.y {
					miny = fin.y
					h = inicio.y - fin.y
				}
				aabb := rl.Rectangle{inicio.x - thickness / 2, miny, thickness, h}
				// left wall is border when columnaActual == 0
				is_border := columnaActual == 0
				tipo_val := 0
				if vertice == vSalida && salidaWall == 3 {
					tipo_val = 2
				} else if is_border {
					tipo_val = 0
				} else {
					tipo_val = 1
				}
				append(
					&paredes,
					Pared {
						inicio = inicio,
						fin = fin,
						tipo = tipo_val,
						color = rl.YELLOW,
						thickness = thickness,
						aabb = aabb,
						revelada = false,
					},
				)
			}
		}
	}

	return paredes, vEntrada, vSalida

}

dibujarLaberinto :: proc() {
	paredes := g.laberintoActual

	for p in paredes {
		// no dibujar paredes internas (tipo == 1) a menos que el flag esté activo
		// Las paredes que han sido reveladas deben mostrarse siempre
		if p.tipo == 1 && !g.show_internal_walls && !p.revelada {
			continue
		}
		draw_color := p.color
		// si es la pared de salida (tipo == 2) mostrarla en verde solo cuando se presiona M
		if p.tipo == 2 && g.show_internal_walls {
			draw_color = rl.GREEN
		}
		rl.DrawLineEx(p.inicio, p.fin, p.thickness, draw_color)
	}

}

resolverColisionesJugador :: proc() {
	pr := g.player_aabb
	// iterar sobre paredes y resolver por el eje de menor penetración (slide)
	for i in 0 ..< len(g.laberintoActual) {
		p := g.laberintoActual[i]
		wa := p.aabb

		// usar CheckCollisionRecs para detección simple
		if rl.CheckCollisionRecs(pr, wa) {
			// if this is an internal wall and currently hidden, trigger screen shake + stun and push player
			if p.tipo == 1 && !g.show_internal_walls {
				// if wall already revealed, treat as visible (no stun)
				if p.revelada {
					// fallthrough to normal resolution below
				} else {
					// reveal this wall permanently for this level
					g.laberintoActual[i].revelada = true
					// push player opposite from wall center and apply stun/shake once
					wall_cx := wa.x + wa.width / 2
					wall_cy := wa.y + wa.height / 2
					dx := g.player_pos.x - wall_cx
					dy := g.player_pos.y - wall_cy
					len := math.sqrt(dx * dx + dy * dy)
					nx := f32(0.0)
					ny := f32(0.0)
					if len == 0.0 {
						nx = 0.0
						ny = -1.0
					} else {
						nx = dx / len
						ny = dy / len
					}
					pushDist := f32(40) / f32(4)
					g.player_pos.x += nx * pushDist
					g.player_pos.y += ny * pushDist
					g.stun_timer = f32(2.0)
					g.shake_timer = f32(1.0)
					// update player AABB after push
					g.player_aabb.x = g.player_pos.x - g.player_aabb.width / 2
					g.player_aabb.y = g.player_pos.y - g.player_aabb.height / 2
					pr = g.player_aabb
					continue
				}
			}
			// calcular overlap
			right := pr.x + pr.width
			if wa.x + wa.width < right {
				right = wa.x + wa.width
			}

			left := pr.x
			if wa.x > left {
				left = wa.x
			}

			overlapW := right - left

			bottom := pr.y + pr.height
			if wa.y + wa.height < bottom {
				bottom = wa.y + wa.height
			}

			top := pr.y
			if wa.y > top {
				top = wa.y
			}

			overlapH := bottom - top

			if overlapW > 0 && overlapH > 0 {
				// centro de player y wall
				cx := g.player_pos.x
				cy := g.player_pos.y
				wall_cx := wa.x + wa.width / 2
				wall_cy := wa.y + wa.height / 2

				if overlapW < overlapH {
					// resolver en X por slide
					if cx < wall_cx {
						g.player_pos.x -= overlapW
					} else {
						g.player_pos.x += overlapW
					}
				} else {
					// resolver en Y por slide
					if cy < wall_cy {
						g.player_pos.y -= overlapH
					} else {
						g.player_pos.y += overlapH
					}
				}

				// actualizar AABB del jugador tras mover
				g.player_aabb.x = g.player_pos.x - g.player_aabb.width / 2
				g.player_aabb.y = g.player_pos.y - g.player_aabb.height / 2

				// actualizar pr para siguientes comprobaciones
				pr = g.player_aabb
			}
		}
	}
}
