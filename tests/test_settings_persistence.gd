extends SceneTree

func _initialize() -> void:
	var config: Node = get_root().get_node("GameConfig")

	# Stash a recognizable set of settings and persist them.
	config.resolution = Vector2i(1920, 1080)
	config.fullscreen = true
	config.player1_source = config.SOURCE_GAMEPAD
	config.player1_device = 3
	config.player2_keys["swap"] = KEY_K
	config.save_settings()

	# Clobber in-memory state, then reload from disk.
	config.resolution = Vector2i(0, 0)
	config.fullscreen = false
	config.player1_source = config.SOURCE_KEYBOARD
	config.player1_device = 0
	config.player2_keys = {}
	config.load_settings()

	assert(config.resolution == Vector2i(1920, 1080))
	assert(config.fullscreen == true)
	assert(config.player1_source == config.SOURCE_GAMEPAD)
	assert(config.player1_device == 3)
	assert(int(config.player2_keys["swap"]) == KEY_K)

	# Clean up so the saved file doesn't leak into real game sessions.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(config.SETTINGS_PATH))

	print("ALL TESTS PASSED")
	quit()
