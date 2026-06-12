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

	# --- receive_garbage stacks pieces in incoming_garbage ---
	board.receive_garbage([{"w": 3, "h": 1}])
	assert(board.incoming_garbage == [{"w": 3, "h": 1}])

	# --- _update_incoming_garbage spawns the piece when the spawn area is free ---
	board._update_incoming_garbage()
	assert(board.incoming_garbage.is_empty())

	var found_garbage := false
	for row in range(board.VISIBLE_ROWS):
		for col in range(board.GRID_WIDTH):
			if board.grid[row][col] is GarbageBlock:
				found_garbage = true
	assert(found_garbage)

	# --- spawn area occupied: piece stays queued ---
	_clear(board)
	for col in range(board.GRID_WIDTH):
		board.grid[0][col] = board._spawn_block(0, 0, col)

	board.receive_garbage([{"w": 6, "h": 1}])
	board._update_incoming_garbage()
	assert(board.incoming_garbage == [{"w": 6, "h": 1}])

	print("ALL TESTS PASSED")
	quit()
	return true
