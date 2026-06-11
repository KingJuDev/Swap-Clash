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

	# Spawn a 2x2 garbage block at columns 1-2, rows 9-10.
	var g: Variant = board._spawn_garbage_block(Vector2i(1, 9), 2, 2)
	assert(g.width == 2 and g.height == 2)
	assert(board.grid[9][1] == g and board.grid[9][2] == g)
	assert(board.grid[10][1] == g and board.grid[10][2] == g)
	assert(g.position == board._cell_position(1, 9))

	# _find_matches must not crash when garbage cells are present, and must
	# not consider them part of any match.
	for col in range(3, 6):
		board.grid[11][col] = board._spawn_block(0, 11, col)
	var matches: Array = board._find_matches()
	assert(matches.size() == 3)

	# A rise step must shift the garbage block's origin up by 1 without error.
	board._do_rise_step()
	assert(board.game_over_flag == false)
	assert(g.origin == Vector2i(1, 8))
	assert(board.grid[8][1] == g and board.grid[8][2] == g)
	assert(board.grid[9][1] == g and board.grid[9][2] == g)

	print("ALL TESTS PASSED")
	quit()
	return true
