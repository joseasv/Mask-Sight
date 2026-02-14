package game

// state manager doesn't need raylib directly
GameState :: enum {
	Title,
	Select,
	Story,
	Play,
	Final,
}

current_state: GameState = GameState.Title

state_machine_init :: proc() {
	current_state = GameState.Title
	g.state_requested = -1
	// call enter of initial state
	state_title_on_enter()
}

transition_to :: proc(s: GameState) {
	// call exit hook if needed (not implemented)
	current_state = s
	g.state_requested = -1
	// call on_enter of new state
	switch current_state {
	case .Title:
		state_title_on_enter()
	case .Select:
		state_select_on_enter()
	case .Story:
		state_story_on_enter()
	case .Play:
		state_play_on_enter()
	case .Final:
		state_final_on_enter()
	}
}

state_machine_update :: proc() {
	// if external request pending, transition
	if g.state_requested != -1 {
		transition_to(GameState(g.state_requested))
	}

	// call current state's update
	switch current_state {
	case .Title:
		state_title_update()
	case .Select:
		state_select_update()
	case .Story:
		state_story_update()
	case .Play:
		state_play_update()
	case .Final:
		state_final_update()
	}

}

state_machine_draw :: proc() {
	switch current_state {
	case .Title:
		state_title_draw()
	case .Select:
		state_select_draw()
	case .Story:
		state_story_draw()
	case .Play:
		state_play_draw()
	case .Final:
		state_final_draw()
	}
}
