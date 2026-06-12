extends SceneTree

const BoardScene := preload("res://scenes/Board.tscn")

var _board: Variant = null
var _emitted := []

func _initialize() -> void:
	_board = BoardScene.instantiate()
	get_root().add_child(_board)

func _clear(board: Variant) -> void:
	for row in range(board.TOTAL_ROWS):
		for col in range(board.GRID_WIDTH):
			var b: Variant = board.grid[row][col]
			if b != null:
				b.queue_free()
			board.grid[row][col] = null

func _process(_delta: float) -> bool:
	var board: Variant = _board
	_clear(board)

	board.chain_count = 3
	board.chain_max = 3
	board.garbage_sent.connect(func(pieces: Array): _emitted.append(pieces))

	board._end_chain()

	assert(_emitted == [[{"w": 6, "h": 2}]])
	assert(board.chain_count == 0)
	assert(board.chain_max == 0)
	assert(board.combo_max == 0)

	print("ALL TESTS PASSED")
	quit()
	return true
