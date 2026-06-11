extends SceneTree

const MatchScene := preload("res://scenes/Match.tscn")

var _match: Variant = null

func _initialize() -> void:
	_match = MatchScene.instantiate()
	get_root().add_child(_match)

func _process(_delta: float) -> bool:
	var m: Variant = _match

	# No gamepads connected in headless mode -> waiting screen, boards paused.
	assert(m.waiting_panel.visible == true)
	assert(m.board1.is_processing() == false)
	assert(m.board2.is_processing() == false)
	assert(m.board1.input_device == 0)
	assert(m.board2.input_device == 1)

	# garbage_sent on one board routes to receive_garbage on the other.
	m.board1.garbage_sent.emit(5)
	assert(m.board2.pending_garbage.size() == 1)
	assert(m.board2.pending_garbage[0].power == 5)

	m.board2.garbage_sent.emit(3)
	assert(m.board1.pending_garbage.size() == 1)
	assert(m.board1.pending_garbage[0].power == 3)

	# game_over on board1 means player 2 wins.
	m.board1.game_over.emit()
	assert(m.end_panel.visible == true)
	assert(m.end_label.text == "Joueur 2 gagne !")
	assert(m.board1.is_processing() == false)
	assert(m.board2.is_processing() == false)

	print("ALL TESTS PASSED")
	quit()
	return true
