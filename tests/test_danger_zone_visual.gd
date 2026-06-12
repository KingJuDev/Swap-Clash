extends SceneTree

const BoardScene := preload("res://scenes/Board.tscn")

var _board: Variant = null

func _initialize() -> void:
	_board = BoardScene.instantiate()
	get_root().add_child(_board)

func _clear(board: Variant) -> void:
	for row in range(board.TOTAL_ROWS):
		for col in range(board.GRID_WIDTH):
			var b: Variant = board.grid[row][col]
			if b != null:
				b.queue_free()
			board.grid[row][col] = null

func _process(_delta: float) -> bool:
	var board: Variant = _board
	_clear(board)

	assert(board._is_in_danger_zone() == false)

	# Fill the top row (alternating colors so it's not also a match) -> danger zone.
	for col in range(board.GRID_WIDTH):
		board.grid[0][col] = board._spawn_block(col % 2, 0, col)
	assert(board._is_in_danger_zone() == true)

	# The pulse timer advances while in the danger zone, and resets when not.
	var delta := 1.0 / 60.0
	board._process(delta)
	assert(board._danger_pulse_t > 0.0)

	_clear(board)
	board._process(delta)
	assert(board._danger_pulse_t == 0.0)

	print("ALL TESTS PASSED")
	quit()
	return true
