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

	# Queue a 1-row garbage block.
	board.receive_garbage([{"w": 3, "h": 1}])

	# This is what _process() calls every frame to deliver queued garbage.
	board._update_incoming_garbage()

	assert(board.incoming_garbage.is_empty())

	var g: Variant = null
	for row in range(board.VISIBLE_ROWS):
		for col in range(board.GRID_WIDTH):
			if board.grid[row][col] is GarbageBlock:
				g = board.grid[row][col]

	assert(g != null)
	assert(g.state == GarbageBlock.State.FLOATING)

	# The board is otherwise empty, so the garbage should fall on its own
	# (without the player swapping) to rest on the floor.
	var delta := 1.0 / 60.0
	for i in range(300):
		board._advance_simulation(delta)

	assert(g.origin.y == board.VISIBLE_ROWS - g.height)
	assert(g.state == GarbageBlock.State.IDLE)

	print("ALL TESTS PASSED")
	quit()
	return true
