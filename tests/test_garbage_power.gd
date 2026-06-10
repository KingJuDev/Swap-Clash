extends SceneTree

const BoardScene := preload("res://scenes/Board.tscn")

var _board: Variant = null

func _initialize() -> void:
	_board = BoardScene.instantiate()
	get_root().add_child(_board)

func _process(_delta: float) -> bool:
	var board: Variant = _board

	# No chain, combo too small -> no garbage
	assert(board._garbage_power_for(3, 1) == 0)

	# Combo table: combo 4->3, 5->4, 6->5, 7->6, capped at 6
	assert(board._garbage_power_for(4, 1) == 3)
	assert(board._garbage_power_for(5, 1) == 4)
	assert(board._garbage_power_for(6, 1) == 5)
	assert(board._garbage_power_for(7, 1) == 6)
	assert(board._garbage_power_for(10, 1) == 6)

	# Chain table: power = 6 * (chain - 1), capped at chain 13 (height 12)
	assert(board._garbage_power_for(3, 2) == 6)
	assert(board._garbage_power_for(3, 3) == 12)
	assert(board._garbage_power_for(3, 4) == 18)
	assert(board._garbage_power_for(3, 13) == 72)
	assert(board._garbage_power_for(3, 20) == 72)

	print("ALL TESTS PASSED")
	quit()
	return true
