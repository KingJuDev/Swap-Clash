extends SceneTree

const BoardScene := preload("res://scenes/Board.tscn")

var _board: Variant = null

func _initialize() -> void:
	_board = BoardScene.instantiate()
	get_root().add_child(_board)

func _process(_delta: float) -> bool:
	var board: Variant = _board

	assert(board.MAX_GARBAGE_HEIGHT == 11)

	assert(board._garbage_shape_for_power(0) == {"height": 0, "width": 0})
	assert(board._garbage_shape_for_power(3) == {"height": 1, "width": 3})
	assert(board._garbage_shape_for_power(6) == {"height": 1, "width": 6})
	assert(board._garbage_shape_for_power(7) == {"height": 2, "width": 6})
	assert(board._garbage_shape_for_power(12) == {"height": 2, "width": 6})
	assert(board._garbage_shape_for_power(13) == {"height": 3, "width": 6})
	assert(board._garbage_shape_for_power(72) == {"height": 11, "width": 6})

	print("ALL TESTS PASSED")
	quit()
	return true
