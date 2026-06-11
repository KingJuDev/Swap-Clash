extends SceneTree

const BoardScene := preload("res://scenes/Board.tscn")

var _board: Variant = null
var _garbage: Variant = null
var _emitted_power := -1
var _started := false
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

	if not _started:
		_started = true
		seed(42)
		_clear(board)

		# Garbage 3x2 at columns 0-2, rows 9-10.
		_garbage = board._spawn_garbage_block(Vector2i(0, 9), 3, 2)

		# Horizontal 3-match of color 0 at row 10, columns 3-5.
		# Cell (3,10) is adjacent to garbage cell (2,10) -> garbage must shatter.
		for col in range(3, 6):
			board.grid[10][col] = board._spawn_block(0, 10, col)

		board.garbage_sent.connect(func(power: int): _emitted_power = power)
		board._resolve_matches()

		# garbage_sent must fire synchronously (before the first await):
		# combo of 3, no chain bonus -> power 0, nothing emitted yet.
		assert(_emitted_power == -1)
		return false

	_frame += 1
	if _frame < 180:
		return false

	# The garbage block lost its bottom row: height shrank from 2 to 1.
	assert(_garbage.height == 1)
	assert(_garbage.width == 3)

	# Either the 3 freed panels remain (no further chain) or they matched
	# again and were cleared (chain) - both are valid outcomes.
	var total_blocks := 0
	for row in range(board.VISIBLE_ROWS):
		for col in range(board.GRID_WIDTH):
			if board.grid[row][col] is Block:
				total_blocks += 1
	assert(total_blocks == 0 or total_blocks == 3)

	print("ALL TESTS PASSED")
	quit()
	return true
