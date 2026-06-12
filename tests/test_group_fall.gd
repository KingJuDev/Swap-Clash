extends SceneTree

const BoardScene := preload("res://scenes/Board.tscn")

var _board: Variant = null
var _btop: Variant = null
var _bmid: Variant = null
var _bbot: Variant = null
var _frame := 0

func _clear(board: Variant) -> void:
	for row in range(board.TOTAL_ROWS):
		for col in range(board.GRID_WIDTH):
			var b: Variant = board.grid[row][col]
			if b != null:
				b.queue_free()
			board.grid[row][col] = null

func _initialize() -> void:
	_board = BoardScene.instantiate()
	get_root().add_child(_board)
	# Drive gravity by hand for determinism.
	_board.set_process(false)

func _process(_delta: float) -> bool:
	var board: Variant = _board

	if _frame == 0:
		_clear(board)
		# Three distinct-colored blocks stacked at rows 3/4/5, col 2; empty below.
		_btop = board._spawn_block(0, 3, 2); board.grid[3][2] = _btop
		_bmid = board._spawn_block(1, 4, 2); board.grid[4][2] = _bmid
		_bbot = board._spawn_block(2, 5, 2); board.grid[5][2] = _bbot

	board._update_blocks(1.0 / 60.0)
	_frame += 1

	# Mid-fall (past the 0.2s float delay, well before landing): the whole column
	# must be falling together, one cell apart — not staggered.
	if _frame == 18:
		var all_falling: bool = _btop.state == Block.State.FALLING \
			and _bmid.state == Block.State.FALLING \
			and _bbot.state == Block.State.FALLING
		var spaced: bool = absf((_bmid.position.y - _btop.position.y) - board.CELL_SIZE) < 0.5 \
			and absf((_bbot.position.y - _bmid.position.y) - board.CELL_SIZE) < 0.5
		if not (all_falling and spaced):
			print("FAIL: blocks not falling together (staggered) — states %s/%s/%s" % [
				_btop.state, _bmid.state, _bbot.state])
			quit()
			return true
		return false

	if _frame < 80:
		return false

	# They settle together onto the floor, stacked 9/10/11.
	var landed: bool = _btop.state == Block.State.IDLE and _btop.grid_pos == Vector2i(2, 9) \
		and _bmid.state == Block.State.IDLE and _bmid.grid_pos == Vector2i(2, 10) \
		and _bbot.state == Block.State.IDLE and _bbot.grid_pos == Vector2i(2, 11)
	if landed:
		print("ALL TESTS PASSED")
	else:
		print("FAIL: blocks did not settle stacked 9/10/11")
	quit()
	return true
