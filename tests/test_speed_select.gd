extends SceneTree

# Speed-select screen: reflects GameConfig.rise_level, left/right adjust the value
# (clamped 1-9).

const SpeedSelectScene := preload("res://scenes/SpeedSelect.tscn")

var _menu: Variant = null
var _setup := false

func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	_menu._unhandled_input(ev)

func _process(_delta: float) -> bool:
	var config: Variant = get_root().get_node("GameConfig")

	if not _setup:
		# Set the level after the autoload's _ready, then build the screen so its
		# _ready reads our value.
		config.rise_level = 3
		_menu = SpeedSelectScene.instantiate()
		get_root().add_child(_menu)
		_setup = true
		return false

	# Initial value comes from GameConfig.
	assert(_menu._level == 3)
	assert(_menu.value_label.text == "3")

	# ui_right / ui_left adjust the value.
	_press("ui_right")
	assert(_menu._level == 4)
	assert(_menu.value_label.text == "4")
	_press("ui_left")
	assert(_menu._level == 3)

	# Clamped to [1, 9].
	_menu._change(100)
	assert(_menu._level == 9)
	assert(_menu.value_label.text == "9")
	_menu._change(-100)
	assert(_menu._level == 1)
	assert(_menu.value_label.text == "1")

	print("ALL TESTS PASSED")
	quit()
	return true
