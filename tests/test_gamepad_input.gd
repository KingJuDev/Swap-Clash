extends SceneTree

const BoardScene := preload("res://scenes/Board.tscn")

var _board: Variant = null
var _phase := 0
var _frame := 0

func _initialize() -> void:
	_board = BoardScene.instantiate()
	get_root().add_child(_board)

func _process(_delta: float) -> bool:
	var board: Variant = _board

	if _phase == 0:
		assert(board.input_device == 0)
		var start_x: int = board.cursor_pos.x

		var event := InputEventJoypadButton.new()
		event.device = 0
		event.button_index = JOY_BUTTON_DPAD_RIGHT
		event.pressed = true
		Input.parse_input_event(event)

		_phase = 1
		_frame = 0
		return false

	if _phase == 1:
		_frame += 1
		if _frame < 5:
			return false
		assert(board.cursor_pos.x == board.GRID_WIDTH / 2)

		var release := InputEventJoypadButton.new()
		release.device = 0
		release.button_index = JOY_BUTTON_DPAD_RIGHT
		release.pressed = false
		Input.parse_input_event(release)

		# Input on a different device must not move this board's cursor.
		var other := InputEventJoypadButton.new()
		other.device = 1
		other.button_index = JOY_BUTTON_DPAD_LEFT
		other.pressed = true
		Input.parse_input_event(other)

		_phase = 2
		_frame = 0
		return false

	_frame += 1
	if _frame < 5:
		return false

	assert(board.cursor_pos.x == board.GRID_WIDTH / 2)
	print("ALL TESTS PASSED")
	quit()
	return true
