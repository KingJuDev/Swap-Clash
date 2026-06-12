extends SceneTree

func _process(_delta: float) -> bool:
	var label := Label.new()
	get_root().add_child(label)

	NeonTheme.animate_chain_label(label, 13)
	assert(label.text == "Chain x13!")

	NeonTheme.animate_chain_label(label, 14)
	assert(label.text == "Chain x?!")

	print("ALL TESTS PASSED")
	quit()
	return true
