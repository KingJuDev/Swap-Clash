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

	# Match A: a 3-in-a-row of color 0 at the bottom row, columns 0-2.
	# None of these blocks have from_chain set, so this match is NOT a chain link.
	var bottom: int = board.VISIBLE_ROWS - 1
	for col in range(3):
		var b: Block = board._spawn_block(0, bottom, col)
		board.grid[bottom][col] = b

	# Block B: an unrelated block at column 5, different color, that "landed this frame"
	# carrying a stale from_chain=true flag (e.g. it floated/fell earlier without
	# itself completing a match). It is NOT part of any match this frame.
	var block_b: Block = board._spawn_block(1, bottom, 5)
	board.grid[bottom][5] = block_b
	block_b.from_chain = true
	board._landed_this_frame = [block_b]

	board._check_matches()

	# Match A formed (chain_count starts at 1, none of its blocks are chain links).
	assert(board.chain_count == 1)
	assert(board.chain_max == 1)

	# Block B was not part of the match this frame, so its stale from_chain flag
	# must be cleared, even though matches overall was non-empty.
	assert(block_b.from_chain == false)

	print("ALL TESTS PASSED")
	quit()
	return true
