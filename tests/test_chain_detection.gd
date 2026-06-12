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

func _step(board: Variant) -> void:
	var delta := 1.0 / 60.0
	board._update_blocks(delta)
	board._update_garbage_blocks(delta)
	board._check_matches()

func _process(_delta: float) -> bool:
	var board: Variant = _board
	_clear(board)

	# Two color-0 blocks already resting at the floor, columns 0-1.
	board.grid[11][0] = board._spawn_block(0, 11, 0)
	board.grid[11][1] = board._spawn_block(0, 11, 1)
	# A third color-0 block falling from row 5, column 2 -> completes a 3-match.
	board.grid[5][2] = board._spawn_block(0, 5, 2)

	var matched := false
	for i in range(100):
		_step(board)
		var b: Variant = board.grid[11][2]
		if b is Block and b.state == Block.State.MATCHED:
			matched = true
			break

	assert(matched)
	# First match of the cascade: no from_chain blocks involved -> new chain.
	assert(board.chain_count == 1)
	assert(board.chain_max == 1)
	assert(board.combo_max == 3)

	# Run the flash + clear timers to completion.
	for i in range(50):
		_step(board)

	for col in range(3):
		assert(board.grid[11][col] == null)

	# Board is settled and a cascade happened (chain_max == 1, combo only) ->
	# _end_chain resets counters and does not emit a chain pad (chain_max < 2).
	assert(board._is_board_settled() == true)
	board._end_chain()
	assert(board.chain_count == 0)
	assert(board.chain_max == 0)
	assert(board.combo_max == 0)

	print("ALL TESTS PASSED")
	quit()
	return true
