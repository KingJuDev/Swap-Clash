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

	# Garbage 2x1 floating at row 8, columns 2-3. Empty below it down to the floor (row 11).
	var g: Variant = board._spawn_garbage_block(Vector2i(2, 8), 2, 1)

	# A normal block sits above the garbage, in column 2, with empty space between.
	var b: Variant = board._spawn_block(0, 5, 2)
	board.grid[5][2] = b

	var delta := 1.0 / 60.0
	for i in range(300):
		board._advance_simulation(delta)

	# Garbage falls to the floor (row 11).
	assert(g.origin == Vector2i(2, board.VISIBLE_ROWS - 1))
	assert(board.grid[board.VISIBLE_ROWS - 1][2] == g and board.grid[board.VISIBLE_ROWS - 1][3] == g)

	# The block above falls to rest just above the garbage (row 10).
	assert(b.grid_pos == Vector2i(2, board.VISIBLE_ROWS - 2))
	assert(board.grid[board.VISIBLE_ROWS - 2][2] == b)

	print("ALL TESTS PASSED")
	quit()
	return true
