extends SceneTree

const BoardScene := preload("res://scenes/Board.tscn")

var _full: Variant = null
var _safe: Variant = null
var _setup_done := false
var _frame := 0
var _full_over := false

func _clear(board: Variant) -> void:
	for row in range(board.TOTAL_ROWS):
		for col in range(board.GRID_WIDTH):
			var b: Variant = board.grid[row][col]
			if b != null:
				b.queue_free()
			board.grid[row][col] = null

func _initialize() -> void:
	_full = BoardScene.instantiate()
	get_root().add_child(_full)
	_full.game_over.connect(func(): _full_over = true)

	# A normal board (default fill leaves the top rows empty) must NOT top out.
	_safe = BoardScene.instantiate()
	get_root().add_child(_safe)

func _process(_delta: float) -> bool:
	# Set up on the first frame, once the boards' _ready has populated their grids.
	if not _setup_done:
		_setup_done = true
		# Overflow _full: fill every visible cell in a 2-color checkerboard (no
		# matches, nothing floats) so the top row stays occupied.
		_clear(_full)
		for row in range(_full.VISIBLE_ROWS):
			for col in range(_full.GRID_WIDTH):
				_full.grid[row][col] = _full._spawn_block((row + col) % 2, row, col)
		return false

	_frame += 1
	# Run well past the grace window (TOP_OUT_GRACE = 1.0s of real time; headless
	# runs faster than 60fps, so use a generous frame budget).
	if _frame < 250:
		return false

	assert(_full_over == true)
	assert(_full.game_over_flag == true)
	assert(_safe.game_over_flag == false)

	print("ALL TESTS PASSED")
	quit()
	return true
