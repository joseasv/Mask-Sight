package game

import cq "core:container/queue"
import "core:fmt"
import "core:math/rand"
import "core:slice"
import rl "vendor:raylib"

Pared :: struct {
	inicio: rl.Vector2,
	fin:    rl.Vector2,
	tipo:   int,
}

Laberinto :: struct {
	ady:          [][dynamic]int,
	predecesores: []int,
	filas:        int,
	columnas:     int,
}

crearLaberinto :: proc(filas: int, columnas: int, dificultad: int) -> [dynamic]Pared {
	laberinto := Laberinto {
		filas        = filas,
		columnas     = columnas,
		ady          = make([][dynamic]int, filas * columnas),
		predecesores = make([]int, filas * columnas),
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
	visitados[0] = true

	if dificultad == 1 {
		cola: cq.Queue(int)
		cq.init(&cola)
		cq.push(&cola, 0)

		for cq.len(cola) > 0 {
			v := cq.pop_front(&cola)

			vecinosDesorden := laberinto.ady[v][:]
			rand.shuffle(vecinosDesorden)

			for w in vecinosDesorden {
				if !visitados[w] {
					visitados[w] = true
					laberinto.predecesores[w] = v
					cq.push(&cola, w)
				} else {
					if laberinto.predecesores[v] != w {
						// quitar la conexion en ambas direcciones entre v y w
						for vertice, i in laberinto.ady[w] {
							if vertice == v {
								unordered_remove(&laberinto.ady[w], i)
								fmt.println("quitando el vertice", v, "en la posicion", i)
								break
							}
						}
						for vertice2, j in laberinto.ady[v] {
							if vertice2 == w {
								unordered_remove(&laberinto.ady[v], j)
								fmt.println("quitando el vertice", w, "en la posicion", j)
								break
							}
						}
					}
				}
			}
		}

		fmt.println(laberinto)
	} else {

	}

	// Construir slice de paredes a partir del grafo resultante
	tamCelda := f32(40)
	paredes := make([dynamic]Pared, 0)

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
				append(&paredes, Pared{inicio = inicio, fin = fin, tipo = 0})
			}

			// pared inferior (horizontal) — evitar duplicados usando solo la pared inferior
			if filaActual == filas - 1 ||
			   !slice.contains(laberinto.ady[vertice][:], vertice + columnas) {
				inicio := rl.Vector2{x, y + tamCelda}
				fin := rl.Vector2{x + tamCelda, y + tamCelda}
				append(&paredes, Pared{inicio = inicio, fin = fin, tipo = 1})
			}

			// pared superior (solo en la primera fila)
			if filaActual == 0 {
				inicio := rl.Vector2{x, y}
				fin := rl.Vector2{x + tamCelda, y}
				append(&paredes, Pared{inicio = inicio, fin = fin, tipo = 2})
			}

			// pared izquierda (solo en la primera columna)
			if columnaActual == 0 {
				inicio := rl.Vector2{x, y}
				fin := rl.Vector2{x, y + tamCelda}
				append(&paredes, Pared{inicio = inicio, fin = fin, tipo = 3})
			}
		}
	}

	return paredes

}

dibujarLaberinto :: proc() {
	paredes := g.laberintoActual

	for p in paredes {
		rl.DrawLine(i32(p.inicio.x), i32(p.inicio.y), i32(p.fin.x), i32(p.fin.y), rl.YELLOW)
	}

}
