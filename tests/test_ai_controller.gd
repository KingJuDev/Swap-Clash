extends SceneTree

const BoardScene := preload("res://scenes/Board.tscn")

var _board: Variant = null
var _phase := 0
var _frame := 0
var _target_col := 0

func _initialize() -> void:
	_board = BoardScene.instantiate()
	_board.input_source = "ai"
	_board.ai = AIController.new("difficile")
	get_root().add_child(_board)

func _process(_delta: float) -> bool:
	var board: Variant = _board

	if _phase == 0:
		# Pin a fixed plan two cells to the right on the cursor's own row, and
		# stop the controller from re-planning so we can observe the cursor
		# tracking the target via virtual button presses.
		_target_col = clampi(board.cursor_pos.x + 2, 0, board.GRID_WIDTH - 2)
		board.ai._plan = {"row": board.cursor_pos.y, "col": _target_col}
		board.ai._think_timer = 999.0
		board.ai._move_timer = 0.0
		_phase = 1
		_frame = 0
		return false

	_frame += 1
	if board.cursor_pos.x == _target_col:
		print("ALL TESTS PASSED")
		quit()
		return true
	assert(_frame < 240) # AI should have walked the cursor to the target by now
	return false
