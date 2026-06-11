extends SceneTree

const SetupMenuScene := preload("res://scenes/SetupMenu.tscn")

var _menu: Variant = null

func _initialize() -> void:
	_menu = SetupMenuScene.instantiate()
	get_root().add_child(_menu)

func _process(_delta: float) -> bool:
	var menu: Variant = _menu
	var config: Variant = get_root().get_node("GameConfig")

	# Headless: no joypads connected -> only "Clavier" for each player.
	assert(menu.player1_option.item_count == 1)
	assert(menu.player1_option.get_item_text(0) == "Clavier")
	assert(menu.player1_option.selected == 0)
	assert(menu.player2_option.item_count == 1)
	assert(menu.player2_option.get_item_text(0) == "Clavier")
	assert(menu.player2_option.selected == 0)

	# Starting with default selection (Clavier/Clavier) writes to GameConfig.
	menu._on_start_pressed()
	assert(config.player1_source == config.SOURCE_KEYBOARD)
	assert(config.player2_source == config.SOURCE_KEYBOARD)

	print("ALL TESTS PASSED")
	quit()
	return true
