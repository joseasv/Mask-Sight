package game

import cq "core:container/queue"
import "core:fmt"
import "core:math/rand"
import "core:slice"
import rl "vendor:raylib"

Laberinto :: struct {
	ady:          [][dynamic]int,
	predecesores: []int,
	filas:        int,
	columnas:     int,
}

crearLaberinto :: proc(filas: int, columnas: int, dificultad: int) -> Laberinto {
	laberinto := Laberinto {
		filas        = filas,
		columnas     = columnas,
		ady          = make([][dynamic]int, filas * columnas),
		predecesores = make([]int, filas * columnas),
	}

	for filaActual in 0 ..< filas {
		for columnaActual in 0 ..< columnas {
			vertice := filaActual * columnas + columnaActual
			if columnaActual < filas - 1 {
				append(&laberinto.ady[vertice], vertice + 1)
				append(&laberinto.ady[vertice + 1], vertice)
			}
			if filaActual < columnas - 1 {
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
						for vertice, i in laberinto.ady[w] {
							if vertice == v {
								unordered_remove(&laberinto.ady[w], i)
								fmt.println("quitando el vertice", v, "en la posicion", i)
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

	return laberinto

}

dibujarLaberinto :: proc() {
	laberinto := g.laberintoActual
	tamCelda := 40
	//mitadCelda := tamCelda / 2

	for filaActual in 0 ..< laberinto.filas {
		for columnaActual in 0 ..< laberinto.columnas {
			vertice := filaActual * laberinto.columnas + columnaActual

			// pared derecha
			if !slice.contains(laberinto.ady[vertice][:], vertice + 1) {
				//fmt.println("el vertice", vertice, "tiene una pared a la derecha")
				rl.DrawLine(
					i32((columnaActual) * tamCelda + tamCelda),
					i32(filaActual * tamCelda),
					i32((columnaActual) * tamCelda + tamCelda),
					i32((filaActual * tamCelda + tamCelda)),
					rl.YELLOW,
				)
			}

			//pared izquierda
			if !slice.contains(laberinto.ady[vertice][:], vertice - 1) {
				//fmt.println("el vertice", vertice, "tiene una pared a la izquierda")
				rl.DrawLine(
					i32(columnaActual * tamCelda),
					i32(filaActual * tamCelda),
					i32(columnaActual * tamCelda),
					i32(filaActual * tamCelda + tamCelda),
					rl.BLUE,
				)
			}

			// pared derecha
			if !slice.contains(laberinto.ady[vertice][:], vertice + laberinto.columnas) {
				//fmt.println("el vertice", vertice, "tiene una pared inferior")
				rl.DrawLine(
					i32((columnaActual) * tamCelda),
					i32(filaActual * tamCelda + tamCelda),
					i32((columnaActual) * tamCelda + tamCelda),
					i32((filaActual * tamCelda + tamCelda)),
					rl.YELLOW,
				)
			}

			//pared izquierda
			if !slice.contains(laberinto.ady[vertice][:], vertice - laberinto.columnas) {
				//fmt.println("el vertice", vertice, "tiene una pared superior")
				rl.DrawLine(
					i32((columnaActual) * tamCelda),
					i32(filaActual * tamCelda),
					i32((columnaActual) * tamCelda + tamCelda),
					i32((filaActual * tamCelda)),
					rl.YELLOW,
				)
			}
		}
	}

}
