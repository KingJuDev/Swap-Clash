extends SceneTree

func _initialize() -> void:
	# GameConfig est un autoload : il doit être accessible comme un singleton global.
	# Note : dans un script qui `extends SceneTree` exécuté via `--headless --script`,
	# l'identifiant global "GameConfig" n'est pas résolu par le compilateur GDScript
	# (limitation connue de Godot 4.6 en mode --script, cf. issues godotengine/godot
	# #78587 et #111515 : le node autoload est bien ajouté à /root, mais l'injection
	# de l'identifiant global au moment de la compilation n'a lieu que pour les
	# scripts attachés à des nodes de scène, pas pour le script SceneTree lui-même).
	# On accède donc au même singleton via /root/GameConfig (le node autoload réel,
	# pas une instance préchargée séparément) ; depuis SetupMenu/Match (Tasks 3-4),
	# qui sont des scripts Node/Node2D, l'identifiant global "GameConfig" fonctionne
	# normalement.
	var game_config: Node = get_root().get_node("GameConfig")

	assert(game_config.player1_source == game_config.SOURCE_KEYBOARD)
	assert(game_config.player1_device == 0)
	assert(game_config.player2_source == game_config.SOURCE_KEYBOARD)
	assert(game_config.player2_device == 0)

	game_config.player1_source = game_config.SOURCE_GAMEPAD
	game_config.player1_device = 1
	assert(game_config.player1_source == game_config.SOURCE_GAMEPAD)
	assert(game_config.player1_device == 1)

	# Rise speed level defaults to 5 and is settable.
	assert(game_config.rise_level == 5)
	game_config.rise_level = 7
	assert(game_config.rise_level == 7)

	print("ALL TESTS PASSED")
	quit()
