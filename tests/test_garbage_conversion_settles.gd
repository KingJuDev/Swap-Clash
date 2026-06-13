extends SceneTree

# Regression guard for the rise-freeze bug: after a garbage block is shattered by
# an adjacent match, conversion must complete and the board must become settled
# again (so the rise can resume). Previously the conversion ran in a
# fire-and-forget coroutine; if it failed to finish the garbage stayed FLASHING
# and the board never settled.

const BoardScene := preload("res://scenes/Board.tscn")

var _board: Variant = null
var _garbage: Variant = null
var _started := false
var _start_time_ms := 0

# Generous wall-clock bound: flash (0.6s) + 2 layers * 1.0s + fall/settle margin.
const TIMEOUT_MS := 6000

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
		# 3x2 garbage at cols 0-2, rows 9-10.
		_garbage = board._spawn_garbage_block(Vector2i(0, 9), 3, 2)
		# Horizontal 3-match adjacent to the garbage's right edge.
		for col in range(3, 6):
			board.grid[10][col] = board._spawn_block(0, 10, col)
		board._check_matches()
		# Conversion has started: the garbage is now flashing (not settled).
		assert(_garbage.state == GarbageBlock.State.FLASHING)
		assert(not board._is_board_settled())
		_start_time_ms = Time.get_ticks_msec()
		return false

	# The board's own _process drives _update_garbage_blocks each frame.
	if not is_instance_valid(_garbage) and board._is_board_settled():
		print("ALL TESTS PASSED")
		quit()
		return true

	# Failure mode: garbage stuck or board never settles within the bound.
	assert(Time.get_ticks_msec() - _start_time_ms < TIMEOUT_MS)
	return false
