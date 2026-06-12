extends SceneTree

const BoardScene := preload("res://scenes/Board.tscn")

var _board: Variant = null
var _frame := 0

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

	if _frame == 0:
		_clear(board)
		# A single block at row 5, col 2; everything below is empty down to the floor.
		board.grid[5][2] = board._spawn_block(0, 5, 2)

	var delta := 1.0 / 60.0
	board._update_blocks(delta)
	_frame += 1

	if _frame == 1:
		var b: Variant = board.grid[5][2]
		assert(b.state == Block.State.FLOATING)
		assert(b.float_timer > 0.0)
		assert(b.from_chain == true)
		return false

	if _frame < 200:
		return false

	# After enough frames, the block has fully fallen to the floor row.
	var b: Variant = board.grid[board.VISIBLE_ROWS - 1][2]
	assert(b is Block)
	assert(b.state == Block.State.IDLE)
	assert(b.grid_pos == Vector2i(2, board.VISIBLE_ROWS - 1))
	assert(absf(b.position.y - (board.VISIBLE_ROWS - 1) * board.CELL_SIZE) < 0.01)

	print("ALL TESTS PASSED")
	quit()
	return true
