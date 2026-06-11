extends SceneTree

const BoardScene := preload("res://scenes/Board.tscn")

var _board1: Variant = null
var _board2: Variant = null
var _phase := 0
var _frame := 0
var _extra_data: int = 0

func _initialize() -> void:
	_board1 = BoardScene.instantiate()
	_board1.input_source = "keyboard"
	_board1.keyboard_scheme = 1
	get_root().add_child(_board1)

	_board2 = BoardScene.instantiate()
	_board2.input_source = "keyboard"
	_board2.keyboard_scheme = 2
	get_root().add_child(_board2)

func _process(_delta: float) -> bool:
	var b1: Variant = _board1
	var b2: Variant = _board2

	if _phase == 0:
		# Player 1: D moves cursor right.
		var p1_right := InputEventKey.new()
		p1_right.physical_keycode = KEY_D
		p1_right.pressed = true
		Input.parse_input_event(p1_right)

		# Player 2: Left arrow moves cursor left.
		var p2_left := InputEventKey.new()
		p2_left.physical_keycode = KEY_LEFT
		p2_left.pressed = true
		Input.parse_input_event(p2_left)

		_phase = 1
		_frame = 0
		return false

	if _phase == 1:
		_frame += 1
		if _frame < 5:
			return false

		assert(b1.cursor_pos.x == clampi(b1.GRID_WIDTH / 2 - 1 + 1, 0, b1.GRID_WIDTH - 2))
		assert(b2.cursor_pos.x == clampi(b2.GRID_WIDTH / 2 - 1 - 1, 0, b2.GRID_WIDTH - 2))

		var p1_right_release := InputEventKey.new()
		p1_right_release.physical_keycode = KEY_D
		p1_right_release.pressed = false
		Input.parse_input_event(p1_right_release)

		var p2_left_release := InputEventKey.new()
		p2_left_release.physical_keycode = KEY_LEFT
		p2_left_release.pressed = false
		Input.parse_input_event(p2_left_release)

		# Player 2 presses Right arrow: should not move player 1's cursor (different scheme).
		var p2_right := InputEventKey.new()
		p2_right.physical_keycode = KEY_RIGHT
		p2_right.pressed = true
		Input.parse_input_event(p2_right)

		_phase = 2
		_frame = 0
		return false

	if _phase == 2:
		_frame += 1
		if _frame < 5:
			return false

		var b1_x_after: int = b1.cursor_pos.x
		assert(b2.cursor_pos.x == b2.GRID_WIDTH / 2 - 1)

		var p2_right_release := InputEventKey.new()
		p2_right_release.physical_keycode = KEY_RIGHT
		p2_right_release.pressed = false
		Input.parse_input_event(p2_right_release)

		# Player 1 fast-rise key (Shift) should not affect player 2.
		var shift_press := InputEventKey.new()
		shift_press.physical_keycode = KEY_SHIFT
		shift_press.pressed = true
		Input.parse_input_event(shift_press)

		_phase = 3
		_frame = 0
		_extra_data = b1_x_after
		return false

	_frame += 1
	if _frame < 2:
		return false

	assert(b1._is_fast_rise_pressed() == true)
	assert(b2._is_fast_rise_pressed() == false)

	var shift_release := InputEventKey.new()
	shift_release.physical_keycode = KEY_SHIFT
	shift_release.pressed = false
	Input.parse_input_event(shift_release)

	print("ALL TESTS PASSED")
	quit()
	return true
