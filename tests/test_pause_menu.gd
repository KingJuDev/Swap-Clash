extends SceneTree

func _process(_delta: float) -> bool:
	var pause: Variant = get_root().get_node("PauseMenu")
	var back_button: Variant = pause.get_node("Panel/VBox/BackButton")
	var quit_game_button: Variant = pause.get_node("Panel/VBox/QuitGameButton")

	# Menu context (no current scene): only Retour + Quitter le jeu.
	pause.open()
	assert(pause._panel.visible)
	assert(paused)
	assert(back_button.visible)
	assert(quit_game_button.visible)
	assert(not pause._restart_button.visible)
	assert(not pause._quit_to_menu_button.visible)

	pause.close()
	assert(not pause._panel.visible)
	assert(not paused)

	# Partie context: Recommencer + Quitter au menu principal appear.
	var fake := Node.new()
	fake.scene_file_path = "res://scenes/Match.tscn"
	get_root().add_child(fake)
	current_scene = fake

	pause.open()
	assert(paused)
	assert(pause._restart_button.visible)
	assert(pause._quit_to_menu_button.visible)
	pause.close()

	print("ALL TESTS PASSED")
	quit()
	return true
