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

	# Three same-color IDLE blocks in a row -> a match.
	for col in range(3):
		board.grid[11][col] = board._spawn_block(0, 11, col)
	assert(board._find_matches().size() == 3)

	# If the middle block is no longer IDLE (already matched / falling /
	# swapping), it must not be considered part of a match.
	board.grid[11][1].state = Block.State.MATCHED
	assert(board._find_matches().is_empty())

	print("ALL TESTS PASSED")
	quit()
	return true
