extends SceneTree

const BoardScene := preload("res://scenes/Board.tscn")

var _board: Variant = null
var _g: Variant = null
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
		# Garbage 2x1 floating at row 8, columns 2-3, empty all the way to the floor.
		_g = board._spawn_garbage_block(Vector2i(2, 8), 2, 1)

	var delta := 1.0 / 60.0
	board._update_garbage_blocks(delta)
	_frame += 1

	if _frame == 1:
		assert(_g.state == GarbageBlock.State.FLOATING)
		assert(_g.float_timer > 0.0)
		return false

	if _frame < 200:
		return false

	assert(_g.state == GarbageBlock.State.IDLE)
	assert(_g.origin == Vector2i(2, board.VISIBLE_ROWS - 1))
	assert(board.grid[board.VISIBLE_ROWS - 1][2] == _g)
	assert(board.grid[board.VISIBLE_ROWS - 1][3] == _g)

	print("ALL TESTS PASSED")
	quit()
	return true
