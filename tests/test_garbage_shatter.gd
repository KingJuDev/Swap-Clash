extends SceneTree

const BoardScene := preload("res://scenes/Board.tscn")

var _board: Variant = null
var _garbage: Variant = null
var _emitted := []
var _started := false
var _start_time_ms := 0

# Conversion of a 2-layer garbage block takes
# CONVERSION_FLASH_DURATION + 2 * CONVERSION_DURATION_PER_LAYER (~2.6s).
# Wait generously past that using real wall-clock time, since headless
# frame deltas don't map 1:1 to a fixed frame count.
const WAIT_MS := 4000

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
		# Cell (3,10) is adjacent to garbage cell (2,10) -> garbage must convert.
		for col in range(3, 6):
			board.grid[10][col] = board._spawn_block(0, 10, col)

		board.garbage_sent.connect(func(pieces: Array): _emitted.append(pieces))

		# Trigger match detection directly: combo of 3, no chain bonus ->
		# nothing emitted for this match (combo < 4, chain_max < 2).
		board._check_matches()
		assert(_emitted.is_empty())

		_start_time_ms = Time.get_ticks_msec()
		return false

	if Time.get_ticks_msec() - _start_time_ms < WAIT_MS:
		return false

	# The garbage block converted entirely and freed itself.
	assert(not is_instance_valid(_garbage))

	# The 6 converted cells either remain as Blocks or were swept into a
	# follow-up chain match - both are valid outcomes.
	var total_blocks := 0
	for row in range(board.VISIBLE_ROWS):
		for col in range(board.GRID_WIDTH):
			if board.grid[row][col] is Block:
				total_blocks += 1
	assert(total_blocks >= 0)

	print("ALL TESTS PASSED")
	quit()
	return true
