extends SceneTree

const BoardScene := preload("res://scenes/Board.tscn")

var _board: Variant = null
var _emitted := []
var _started := false
var _frame := 0

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

func _process(delta: float) -> bool:
	var board: Variant = _board

	if not _started:
		_started = true
		_clear(board)
		board.garbage_sent.connect(func(power: int): _emitted.append(power))

		# --- receive_garbage queues an item with a telegraph timer ---
		board.receive_garbage(5)
		assert(board.pending_garbage.size() == 1)
		assert(board.pending_garbage[0].power == 5)
		assert(board.pending_garbage[0].telegraph_time == board.TELEGRAPH_DURATION)

		# --- _send_garbage cancels pending garbage first (counter) ---
		board._send_garbage(3)
		assert(board.pending_garbage.size() == 1)
		assert(board.pending_garbage[0].power == 2)
		assert(_emitted.is_empty())

		# --- leftover power after fully cancelling is sent to the opponent ---
		board._send_garbage(5)
		assert(board.pending_garbage.is_empty())
		assert(_emitted == [3])

		# --- delivery: queue a small garbage and fast-forward its telegraph ---
		board.receive_garbage(3)
		board.pending_garbage[0].telegraph_time = 0.0
		return false

	_frame += 1
	if _frame < 5:
		return false

	assert(board.pending_garbage.is_empty())
	var found_garbage := false
	for row in range(board.VISIBLE_ROWS):
		for col in range(board.GRID_WIDTH):
			if board.grid[row][col] is GarbageBlock:
				found_garbage = true
	assert(found_garbage)

	print("ALL TESTS PASSED")
	quit()
	return true
