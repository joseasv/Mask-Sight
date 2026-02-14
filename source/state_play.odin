package game

state_play_on_enter :: proc() {
	// start maze based on selected difficulty
	// reset level counter when entering Play

	if g.selected_difficulty == 1 {
		start_new_maze(4, 6)
	} else if g.selected_difficulty == 2 {
		start_new_maze(6, 8)
	} else if g.selected_difficulty == 3 {
		start_new_maze(8, 10)
	} else {
		start_new_maze(4, 6)
	}
}

state_play_update :: proc() {
	// call existing game update logic
	update()


}

state_play_draw :: proc() {
	draw()
}
