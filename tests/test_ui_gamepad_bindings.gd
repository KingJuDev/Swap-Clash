extends SceneTree

func _has_joy_button(action: String, button: int) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton and ev.button_index == button:
			return true
	return false

func _process(_delta: float) -> bool:
	# GameConfig autoload runs _ensure_ui_gamepad_bindings() in _ready, which is
	# applied by the first frame.
	assert(_has_joy_button("ui_accept", JOY_BUTTON_A))
	assert(_has_joy_button("ui_cancel", JOY_BUTTON_B))
	# Existing keyboard bindings must be preserved (regression guard).
	var accept_has_key := false
	for ev in InputMap.action_get_events("ui_accept"):
		if ev is InputEventKey:
			accept_has_key = true
	assert(accept_has_key)
	print("ALL TESTS PASSED")
	quit()
	return true
