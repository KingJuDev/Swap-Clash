extends SceneTree

# The board derives its normal rise speed from GameConfig.rise_level:
# speed = RISE_SPEED_BASE + (level - 1) * RISE_SPEED_STEP.

const BoardScene := preload("res://scenes/Board.tscn")

var _board: Variant = null
var _step := 0

func _process(_delta: float) -> bool:
	var config: Variant = get_root().get_node("GameConfig")

	match _step:
		0:
			config.rise_level = 1
			_board = BoardScene.instantiate()
			get_root().add_child(_board)
			_step = 1
			return false
		1:
			assert(is_equal_approx(_board._rise_speed_normal, 2.0))
			_board.free()
			config.rise_level = 5
			_board = BoardScene.instantiate()
			get_root().add_child(_board)
			_step = 2
			return false
		2:
			assert(is_equal_approx(_board._rise_speed_normal, 6.0))
			_board.free()
			config.rise_level = 9
			_board = BoardScene.instantiate()
			get_root().add_child(_board)
			_step = 3
			return false
		3:
			assert(is_equal_approx(_board._rise_speed_normal, 10.0))
			print("ALL TESTS PASSED")
			quit()
	return false
