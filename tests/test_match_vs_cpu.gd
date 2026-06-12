extends SceneTree

const MatchScene := preload("res://scenes/Match.tscn")

var _done := false

func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true

	var config: Variant = get_root().get_node("GameConfig")
	config.vs_cpu = true
	config.cpu_difficulty = "facile"

	var match_scene: Variant = MatchScene.instantiate()
	get_root().add_child(match_scene)

	# board2 (right) becomes the CPU; board1 (left) stays the human player.
	assert(match_scene.board2.input_source == "ai")
	assert(match_scene.board2.ai != null)
	assert(match_scene.board1.input_source != "ai")

	config.vs_cpu = false # don't leak the CPU flag into other tests
	print("ALL TESTS PASSED")
	quit()
	return true
