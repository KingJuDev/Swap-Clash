extends SceneTree

const BoardScene := preload("res://scenes/Board.tscn")

var _board: Variant = null

func _initialize() -> void:
	_board = BoardScene.instantiate()
	get_root().add_child(_board)

func _process(_delta: float) -> bool:
	var board: Variant = _board

	# Combo too small -> no garbage
	assert(board._garbage_combo_pieces(3) == [])

	# Single-piece combos: W = combo_size - 1, capped at GRID_WIDTH
	assert(board._garbage_combo_pieces(4) == [{"w": 3, "h": 1}])
	assert(board._garbage_combo_pieces(5) == [{"w": 4, "h": 1}])
	assert(board._garbage_combo_pieces(6) == [{"w": 5, "h": 1}])
	assert(board._garbage_combo_pieces(7) == [{"w": 6, "h": 1}])

	# Multi-piece combos: split as evenly as possible, each piece <= GRID_WIDTH
	assert(board._garbage_combo_pieces(8) == [{"w": 4, "h": 1}, {"w": 3, "h": 1}])
	assert(board._garbage_combo_pieces(9) == [{"w": 4, "h": 1}, {"w": 4, "h": 1}])
	assert(board._garbage_combo_pieces(10) == [{"w": 5, "h": 1}, {"w": 4, "h": 1}])
	assert(board._garbage_combo_pieces(11) == [{"w": 5, "h": 1}, {"w": 5, "h": 1}])
	assert(board._garbage_combo_pieces(12) == [{"w": 6, "h": 1}, {"w": 5, "h": 1}])
	assert(board._garbage_combo_pieces(13) == [{"w": 6, "h": 1}, {"w": 6, "h": 1}])
	assert(board._garbage_combo_pieces(14) == [{"w": 5, "h": 1}, {"w": 4, "h": 1}, {"w": 4, "h": 1}])

	print("ALL TESTS PASSED")
	quit()
	return true
