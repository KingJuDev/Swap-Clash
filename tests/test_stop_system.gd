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

	# Outside the danger zone: chain_max=2 (1 link bonus), combo_max=4 (1 extra panel).
	board.chain_max = 2
	board.combo_max = 4
	board._end_chain()
	var expected: float = board.STOP_BASE + board.STOP_PER_CHAIN_LINK * 1 + board.STOP_PER_COMBO_EXTRA * 1
	assert(absf(board.stop_timer - expected) < 0.0001)

	# In the danger zone, the same cascade is multiplied.
	board.stop_timer = 0.0
	for col in range(board.GRID_WIDTH):
		board.grid[0][col] = board._spawn_block(col % 2, 0, col)
	board.chain_max = 2
	board.combo_max = 4
	board._end_chain()
	var expected_danger: float = expected * board.DANGER_ZONE_STOP_MULTIPLIER
	assert(absf(board.stop_timer - expected_danger) < 0.0001)
	_clear(board)

	# stop_timer pauses the rise, and counts down each frame on a settled board.
	board.stop_timer = 0.1
	board.rise_offset = 0.0
	var delta := 1.0 / 60.0
	board._process(delta)
	assert(board.rise_offset == 0.0)
	assert(board.stop_timer < 0.1)

	# Once stop_timer reaches 0, the rise resumes.
	board.stop_timer = 0.0
	board._process(delta)
	assert(board.rise_offset > 0.0)

	print("ALL TESTS PASSED")
	quit()
	return true
