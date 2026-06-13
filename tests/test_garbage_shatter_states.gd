extends SceneTree

# Bug 2: a combo adjacent to garbage must destroy it. The shatter trigger now
# fires for garbage in any state except FLASHING (already mid-conversion), so
# IDLE / FLOATING / FALLING garbage all convert; FLASHING garbage is not
# restarted.

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

# Sets up a 3x1 garbage at row 10 (cols 0-2) plus a 3-match at cols 3-5, with the
# garbage forced into the given state. Returns the garbage block.
func _setup_case(board: Variant, garbage_state: int) -> Variant:
	_clear(board)
	var g: Variant = board._spawn_garbage_block(Vector2i(0, 10), 3, 1)
	g.state = garbage_state
	for col in range(3, 6):
		board.grid[10][col] = board._spawn_block(0, 10, col)
	return g

func _process(_delta: float) -> bool:
	var board: Variant = _board

	# IDLE garbage adjacent to a match -> converts.
	var g_idle: Variant = _setup_case(board, GarbageBlock.State.IDLE)
	board._check_matches()
	assert(g_idle.state == GarbageBlock.State.FLASHING)
	assert(g_idle.convert_timer > 0.0)

	# FLOATING garbage adjacent to a match -> converts.
	var g_floating: Variant = _setup_case(board, GarbageBlock.State.FLOATING)
	board._check_matches()
	assert(g_floating.state == GarbageBlock.State.FLASHING)

	# FALLING garbage adjacent to a match -> converts.
	var g_falling: Variant = _setup_case(board, GarbageBlock.State.FALLING)
	board._check_matches()
	assert(g_falling.state == GarbageBlock.State.FLASHING)

	# Garbage already FLASHING mid-conversion is not restarted.
	var g_flashing: Variant = _setup_case(board, GarbageBlock.State.FLASHING)
	g_flashing.convert_timer = 0.42
	board._check_matches()
	assert(g_flashing.convert_timer == 0.42)

	print("ALL TESTS PASSED")
	quit()
	return true
