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

	# Match 1: a horizontal 3-match of color 0 at the floor (row 11, cols 0-2).
	for col in range(3):
		board.grid[11][col] = board._spawn_block(0, 11, col)

	# Chain-link setup: three isolated color-1 blocks, each in its own row/column
	# (rows 8/9/10, cols 2/1/0 respectively), so none of them form a match by
	# themselves at frame 0. Once match 1 clears, each falls straight down its
	# own column to the floor (row 11). They land at different times (different
	# fall distances), but once all three have landed at row 11 cols 0-2, they
	# form a second 3-match -> chain_count == 2 (each fell, so from_chain == true).
	board.grid[10][0] = board._spawn_block(1, 10, 0)
	board.grid[9][1] = board._spawn_block(1, 9, 1)
	board.grid[8][2] = board._spawn_block(1, 8, 2)

	var delta := 1.0 / 60.0
	var saw_chain_link := false
	for i in range(300):
		board._advance_simulation(delta)
		if board.chain_count == 2:
			saw_chain_link = true
			break

	assert(saw_chain_link)
	assert(board.chain_max == 2)

	# Let the second match resolve and the chain end.
	for i in range(100):
		board._advance_simulation(delta)

	assert(board._is_board_settled() == true)
	# chain_max was reset to 0 by _end_chain inside _advance_simulation once settled.
	assert(board.chain_max == 0)
	assert(board.chain_count == 0)

	for col in range(3):
		assert(board.grid[11][col] == null)
		assert(board.grid[10][col] == null)

	print("ALL TESTS PASSED")
	quit()
	return true
