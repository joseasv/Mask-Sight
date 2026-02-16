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
	visitados:    []bool,
	filas:        int,
	columnas:     int,
}

// Procedimiento auxiliar para crear y configurar la pared
crear_pared :: proc(
	paredes: ^[dynamic]Pared,
	inicio, fin: rl.Vector2,
	es_borde: bool,
	es_salida: bool, // <-- Esto determina si es tipo 2
) {
	grosor := f32(8)

	// Calcular AABB (Caja de colisión)
	min_x := min(inicio.x, fin.x)
	min_y := min(inicio.y, fin.y)
	width := abs(fin.x - inicio.x)
	height := abs(fin.y - inicio.y)

	// Ajuste para que las líneas tengan volumen
	if width < grosor {
		min_x -= grosor / 2
		width = grosor
	}
	if height < grosor {
		min_y -= grosor / 2
		height = grosor
	}

	// Lógica de TIPO y COLOR
	tipo_final := 0
	color_final := rl.YELLOW

	if es_salida {
		tipo_final = 2
		color_final = rl.GREEN // Salida verde
	} else if !es_borde {
		tipo_final = 1 // Pared interna
		color_final = rl.YELLOW
	} else {
		tipo_final = 0 // Borde normal
		color_final = rl.YELLOW
	}

	append(
		paredes,
		Pared {
			inicio    = inicio,
			fin       = fin,
			tipo      = tipo_final,
			color     = color_final,
			thickness = grosor,
			aabb      = rl.Rectangle{min_x, min_y, width, height},
			revelada  = false, // Asumo que empieza oculta
		},
	)
}

vecinosSinAristas :: proc(l: Laberinto, v: int) -> [dynamic]int {
	vecinos := make([dynamic]int, context.temp_allocator)

	if v % l.columnas != 0 {
		if !l.visitados[v - 1] {
			append(&vecinos, v - 1)
		}
	}

	if v % l.columnas != l.columnas - 1 {
		if !l.visitados[v + 1] {
			append(&vecinos, v + 1)
		}

	}

	if v / l.columnas != 0 {
		if !l.visitados[v - l.columnas] {
			append(&vecinos, v - l.columnas)
		}
	}

	if v / l.columnas != l.filas - 1 {
		if !l.visitados[v + l.columnas] {
			append(&vecinos, v + l.columnas)
		}
	}

	return vecinos
}

// Procedimiento para decidir qué pared romper en un borde
obtener_pared_borde :: proc(v: int, filas: int, columnas: int) -> int {
	row := v / columnas
	col := v % columnas

	opciones := make([dynamic]int, context.temp_allocator)
	// No hace falta defer delete si usas temp_allocator dentro del frame

	// 0: Derecha, 1: Abajo, 2: Arriba, 3: Izquierda
	if col == 0 {append(&opciones, 3)} 	// Izquierda
	if col == columnas - 1 {append(&opciones, 0)} 	// Derecha
	if row == 0 {append(&opciones, 2)} 	// Arriba
	if row == filas - 1 {append(&opciones, 1)} 	// Abajo

	if len(opciones) > 0 {
		// Devuelve una opción aleatoria válida
		return rand.choice(opciones[:])
	}
	return -1 // No es un borde (error)
}

crearLaberinto :: proc(filas: int, columnas: int, dificultad: int) -> ([dynamic]Pared, int, int) {
	fmt.println("creando laberinto de", filas, "x", columnas, "con dificultad", dificultad)

	laberinto := Laberinto {
		filas        = filas,
		columnas     = columnas,
		ady          = make([][dynamic]int, filas * columnas),
		visitados    = make([]bool, filas * columnas),
		predecesores = make([]int, filas * columnas),
		distancias   = make([]int, filas * columnas),
	}

	// seleccionar un vértice de entrada aleatorio entre los vértices del borde
	border := make([dynamic]int, context.temp_allocator)
	for r in 0 ..< filas {
		for c in 0 ..< columnas {
			if r == 0 || r == filas - 1 || c == 0 || c == columnas - 1 {
				append(&border, r * columnas + c)
			}
		}
	}
	rand.shuffle(border[:])
	vEntrada := border[0]


	//vEntrada := 0

	// inicializar distancias a -1
	slice.fill(laberinto.distancias, -1)

	laberinto.visitados[vEntrada] = true
	laberinto.distancias[vEntrada] = 0


	if false {
		//if dificultad >= 2 {
		// recorrido en anchura (BFS)
		cola: cq.Queue(int)
		cq.init(&cola)
		cq.push(&cola, vEntrada)

		for cq.len(cola) > 0 {
			v := cq.pop_front(&cola)

			vecinosDesorden := vecinosSinAristas(laberinto, v)
			rand.shuffle(vecinosDesorden[:])

			fmt.println("visitando", v, "vecinos:", vecinosDesorden)

			for w in vecinosDesorden {
				if !laberinto.visitados[w] {
					laberinto.visitados[w] = true
					laberinto.predecesores[w] = v
					laberinto.distancias[w] = laberinto.distancias[v] + 1
					append(&laberinto.ady[v], w)
					append(&laberinto.ady[w], v)
					cq.push(&cola, w)
				}
			}
		}

	} else {
		// RECORRIDO EN PROFUNDIDAD (DFS Iterativo / Recursive Backtracker)

		stack := make([dynamic]int, context.temp_allocator)
		// No olvides limpiar si no usas el temp_allocator globalmente,
		// pero para un frame de generación está bien.

		append(&stack, vEntrada)

		for len(stack) > 0 {
			// 1. PEEK: Miramos el nodo actual (el tope) SIN sacarlo todavía.
			//    Necesitamos mantenerlo en la pila por si tenemos que retroceder (backtrack).
			v := stack[len(stack) - 1]

			// 2. Obtenemos vecinos geométricos (arriba, abajo, izq, der)
			posibles_vecinos := vecinosSinAristas(laberinto, v)

			// 3. Filtrar: Buscamos vecinos que NO hayan sido visitados aún
			vecinos_validos := make([dynamic]int, context.temp_allocator)
			for w in posibles_vecinos {
				if !laberinto.visitados[w] {
					append(&vecinos_validos, w)
				}
			}

			if len(vecinos_validos) > 0 {
				// --- AVANZAR (Digging) ---

				// Elegimos UNO solo al azar (esto da la aleatoriedad)
				w := rand.choice(vecinos_validos[:])

				// Marcamos y conectamos
				laberinto.visitados[w] = true
				laberinto.predecesores[w] = v
				laberinto.distancias[w] = laberinto.distancias[v] + 1

				// Creamos la conexión (tiramos la pared)
				append(&laberinto.ady[v], w)
				append(&laberinto.ady[w], v)

				// Empujamos el NUEVO nodo al stack para continuar desde ahí en la siguiente vuelta
				append(&stack, w)

			} else {
				// --- RETROCEDER (Backtracking) ---

				// Si no hay vecinos válidos, es un callejón sin salida.
				// Ahora sí sacamos 'v' de la pila para volver al nodo anterior (predecesor)
				pop(&stack)
			}
		}

	}

	// Construir slice de paredes a partir del grafo resultante
	tamCelda := f32(128 * 2)
	paredes := make([dynamic]Pared, 0)

	// elegir vSalida: el vértice del borde más lejano desde vEntrada


	// elegir una pared exterior aleatoria para la entrada y la salida
	// Calcular Pared de Entrada
	entradaWall := obtener_pared_borde(vEntrada, filas, columnas)

	maxDist := -1
	vSalida := -1
	for v in border {
		d := laberinto.distancias[v]
		if d > maxDist {
			maxDist = d
			vSalida = v
		}
	}

	for v in border {
		// Ignorar la entrada para que no ponga la salida en el mismo sitio
		if v == vEntrada {continue}

		d := laberinto.distancias[v]

		// Solo consideramos nodos alcanzables (distancia > -1)
		if d > maxDist {
			maxDist = d
			vSalida = v
		}
	}

	// Seguridad: Si por alguna razón vSalida sigue siendo -1 (laberinto roto),
	// forzamos que sea el último del borde diferente a la entrada.
	if vSalida == -1 {
		vSalida = border[len(border) - 1]
		if vSalida == vEntrada {vSalida = border[0]}
	}

	// Calcular Pared de Salida usando la nueva función
	salidaWall := obtener_pared_borde(vSalida, filas, columnas)

	// Debug para ver qué está pasando
	fmt.printf(
		"Entrada: %d (Pared %d) | Salida: %d (Pared %d)\n",
		vEntrada,
		entradaWall,
		vSalida,
		salidaWall,
	)

	for filaActual in 0 ..< filas {
		for columnaActual in 0 ..< columnas {
			vertice := filaActual * columnas + columnaActual

			x := f32(columnaActual) * tamCelda
			y := f32(filaActual) * tamCelda

			// 1. PARED DERECHA
			if columnaActual == columnas - 1 ||
			   !slice.contains(laberinto.ady[vertice][:], vertice + 1) {

				es_salida := (vertice == vSalida && salidaWall == 0)
				crear_pared(
					&paredes,
					{x + tamCelda, y},
					{x + tamCelda, y + tamCelda},
					columnaActual == columnas - 1,
					es_salida,
				)
			}

			// 2. PARED INFERIOR
			if filaActual == filas - 1 ||
			   !slice.contains(laberinto.ady[vertice][:], vertice + columnas) {

				es_salida := (vertice == vSalida && salidaWall == 1)
				crear_pared(
					&paredes,
					{x, y + tamCelda},
					{x + tamCelda, y + tamCelda},
					filaActual == filas - 1,
					es_salida,
				)
			}

			// 3. PARED SUPERIOR (Solo fila 0)
			if filaActual == 0 {
				es_salida := (vertice == vSalida && salidaWall == 2)
				crear_pared(&paredes, {x, y}, {x + tamCelda, y}, true, es_salida)
			}

			// 4. PARED IZQUIERDA (Solo columna 0)
			if columnaActual == 0 {
				es_salida := (vertice == vSalida && salidaWall == 3)
				crear_pared(&paredes, {x, y}, {x, y + tamCelda}, true, es_salida)
			}
		}
	}

	return paredes, vEntrada, vSalida

}

dibujarLaberinto :: proc() {

	tamCelda := f32(128 * 2)
	filas := g.maze_rows
	columnas := g.maze_cols

	for i in 0 ..< filas * 4 {
		for j in 0 ..< columnas * 4 {
			x := f32(j) * tamCelda / 4
			y := f32(i) * tamCelda / 4

			rl.DrawTexturePro(
				g.atlas,
				atlas_textures[.Piso].rect,
				rl.Rectangle{x, y, tamCelda / 4, tamCelda / 4},
				rl.Vector2{0, 0},
				0,
				rl.WHITE,
			)

		}
	}

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

		/*if p.tipo != 2 {
			if p.inicio.y == p.fin.y {
				// horizontal

				dest := rl.Rectangle {
					p.inicio.x,
					p.inicio.y,
					abs(p.fin.x - p.inicio.x),
					atlas_textures[.Pared_Frente].rect.height,
				}


				rl.DrawTexturePro(
					g.atlas,
					atlas_textures[.Pared_Frente].rect,
					dest,
					rl.Vector2{0, atlas_textures[.Pared_Frente].rect.height},
					0,
					rl.WHITE,
				)
			} else {
				dest := rl.Rectangle {
					p.inicio.x,
					p.inicio.y,
					atlas_textures[.Pared_Vertical].rect.width,
					abs(p.fin.y - p.inicio.y),
				}

				rl.DrawTexturePro(
					g.atlas,
					atlas_textures[.Pared_Vertical].rect,
					dest,
					rl.Vector2{atlas_textures[.Pared_Vertical].rect.width / 2, 0},
					0,
					rl.WHITE,
				)

			}
		}*/


	}


}

resolverColisionesJugador :: proc() {
	pr := g.personaje.aabb
	// iterar sobre paredes y resolver por el eje de menor penetración (slide)
	for i in 0 ..< len(g.laberintoActual) {
		p := g.laberintoActual[i]
		wa := p.aabb

		// usar CheckCollisionRecs para detección simple
		if rl.CheckCollisionRecs(pr, wa) {
			// if this is an internal wall and currently hidden, trigger screen shake + stun and push player
			if p.tipo == 1 && !g.show_internal_walls {
				// if wall already revealed, treat as visible (no stun)
				if !p.revelada {

					// reveal this wall permanently for this level
					g.laberintoActual[i].revelada = true
					// push player opposite from wall center and apply stun/shake once
					wall_cx := wa.x + wa.width / 2
					wall_cy := wa.y + wa.height / 2
					dx := g.personaje.pos.x - wall_cx
					dy := g.personaje.pos.y - wall_cy
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
					g.personaje.pos.x += nx * pushDist
					g.personaje.pos.y += ny * pushDist
					g.stun_timer = f32(2.0)
					g.shake_timer = f32(1.0)
					// update player AABB after push
					g.personaje.aabb.x = g.personaje.pos.x - g.personaje.aabb.width / 2
					g.personaje.aabb.y = g.personaje.pos.y - g.personaje.aabb.height / 2
					pr = g.personaje.aabb
					break
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
				cx := g.personaje.pos.x
				cy := g.personaje.pos.y
				wall_cx := wa.x + wa.width / 2
				wall_cy := wa.y + wa.height / 2

				if overlapW < overlapH {
					// resolver en X por slide
					if cx < wall_cx {
						g.personaje.pos.x -= overlapW
					} else {
						g.personaje.pos.x += overlapW
					}
				} else {
					// resolver en Y por slide
					if cy < wall_cy {
						g.personaje.pos.y -= overlapH
					} else {
						g.personaje.pos.y += overlapH
					}
				}

				// actualizar AABB del jugador tras mover
				g.personaje.aabb.x = g.personaje.pos.x - g.personaje.aabb.width / 2
				g.personaje.aabb.y = g.personaje.pos.y - g.personaje.aabb.height / 2

				// actualizar pr para siguientes comprobaciones
				pr = g.personaje.aabb
			}
		}
	}
}
