extends SceneTree

# Builds a ROWS x COLS snapshot of empty cells, ready to be filled.
const ROWS := 12
const COLS := 6

func _make_empty() -> Array:
	var snap := []
	for r in range(ROWS):
		var row := []
		for c in range(COLS):
			row.append(AIBrain.EMPTY)
		snap.append(row)
	return snap

func _initialize() -> void:
	# 1) Horizontal: X X Y X  -> swapping cols 2,3 makes a 3-run of X.
	var h := _make_empty()
	h[11] = [0, 0, 1, 0, AIBrain.EMPTY, AIBrain.EMPTY]
	var hs := AIBrain.best_swap(h)
	assert(not hs.is_empty())
	assert(hs["row"] == 11 and hs["col"] == 2)
	assert(hs["score"] >= 1000)

	# 2) Vertical: complete a vertical triple in column 0 via a row swap.
	var v := _make_empty()
	v[9][0] = 0
	v[10][0] = 0
	v[11][0] = 1
	v[11][1] = 0
	var vs := AIBrain.best_swap(v)
	assert(not vs.is_empty())
	assert(vs["row"] == 11 and vs["col"] == 0)
	assert(vs["score"] >= 1000)

	# 3) Empty board: no legal swap at all.
	assert(AIBrain.best_swap(_make_empty()).is_empty())

	# 4) No immediate match, but a swap that sets up an adjacency is chosen.
	var s := _make_empty()
	s[11] = [0, 1, 0, 2, 3, 4]
	var ss := AIBrain.best_swap(s)
	assert(not ss.is_empty())
	assert(ss["score"] > 0 and ss["score"] < 1000)

	print("ALL TESTS PASSED")
	quit()
