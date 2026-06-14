extends SceneTree

const MatchScene := preload("res://scenes/Match.tscn")

var _match: Variant = null
var _setup := false

func _process(_delta: float) -> bool:
	var config: Variant = get_root().get_node("GameConfig")

	if not _setup:
		# Configure inputs AFTER autoloads' _ready (GameConfig.load_settings runs
		# there) so the saved settings.cfg can't override these test values, then
		# instantiate the match so its _ready reads them.
		config.player1_source = config.SOURCE_KEYBOARD
		config.player1_device = 0
		config.player2_source = config.SOURCE_KEYBOARD
		config.player2_device = 0
		_match = MatchScene.instantiate()
		get_root().add_child(_match)
		_setup = true
		return false

	var m: Variant = _match

	# No waiting screen: both boards start processing immediately.
	assert(m.has_node("WaitingPanel") == false)
	assert(m.board1.is_processing() == true)
	assert(m.board2.is_processing() == true)

	# GameConfig is applied to each board.
	assert(m.board1.input_source == config.SOURCE_KEYBOARD)
	assert(m.board1.keyboard_scheme == 1)
	assert(m.board2.input_source == config.SOURCE_KEYBOARD)
	assert(m.board2.keyboard_scheme == 2)

	# garbage_sent on one board routes to receive_garbage on the other.
	m.board1.garbage_sent.emit([{"w": 5, "h": 1}])
	assert(m.board2.incoming_garbage == [{"w": 5, "h": 1}])

	m.board2.garbage_sent.emit([{"w": 3, "h": 1}])
	assert(m.board1.incoming_garbage == [{"w": 3, "h": 1}])

	# game_over on board1 means player 2 wins.
	m.board1.game_over.emit()
	assert(m.end_panel.visible == true)
	assert(m.end_label.text == "Joueur 2 gagne !")
	assert(m.board1.is_processing() == false)
	assert(m.board2.is_processing() == false)

	print("ALL TESTS PASSED")
	quit()
	return true
