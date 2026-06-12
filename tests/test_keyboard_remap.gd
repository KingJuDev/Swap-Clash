extends SceneTree

const BoardScene := preload("res://scenes/Board.tscn")

var _board: Variant = null

func _initialize() -> void:
	_board = BoardScene.instantiate()
	_board.input_source = "keyboard"
	_board.keyboard_scheme = 1
	get_root().add_child(_board)

func _process(_delta: float) -> bool:
	var config: Node = get_root().get_node("GameConfig")
	var board: Variant = _board

	# With a remapped binding in GameConfig, board.gd reads the custom key.
	config.player1_keys["swap"] = KEY_J
	assert(board._keyboard_keys()["swap"] == KEY_J)

	# Empty bindings fall back to the canonical hardcoded scheme.
	config.player1_keys = {}
	assert(board._keyboard_keys()["swap"] == KEY_SPACE)

	# Restore defaults so other tests / the game see sane bindings.
	config.player1_keys = config.default_keys(1)

	print("ALL TESTS PASSED")
	quit()
	return true
