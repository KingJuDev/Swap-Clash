extends SceneTree

const ControlsScene := preload("res://scenes/ControlsOptions.tscn")

var _menu: Variant = null

func _initialize() -> void:
	_menu = ControlsScene.instantiate()
	get_root().add_child(_menu)

func _process(_delta: float) -> bool:
	var menu: Variant = _menu
	var config: Variant = get_root().get_node("GameConfig")

	# Headless: no joypads connected -> only "Clavier" for each player.
	assert(menu.player1_device.item_count == 1)
	assert(menu.player1_device.get_item_text(0) == "Clavier")
	assert(menu.player2_device.item_count == 1)
	assert(menu.player2_device.get_item_text(0) == "Clavier")

	# Selecting "Clavier" writes a keyboard source to GameConfig.
	menu._on_device_selected(1)
	assert(config.player1_source == config.SOURCE_KEYBOARD)
	assert(config.player1_device == 0)

	# Default remap label reflects the current bound key (Space for player 1 swap).
	var swap_button: Variant = menu._remap_button(1, "swap")
	assert(swap_button.text.find("Échanger") == 0)

	# Remapping: capture a key press and store it in the player's bindings.
	menu._on_remap_pressed(1, "swap", swap_button)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_J
	event.pressed = true
	menu._unhandled_input(event)
	assert(config.player1_keys["swap"] == KEY_J)
	assert(swap_button.text.find("J") != -1)

	print("ALL TESTS PASSED")
	quit()
	return true
