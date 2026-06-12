extends SceneTree

const ROWS := 12
const COLS := 6

# Color ids
const G := 0
const Y := 1
const R := 2
const B := 3

func _make_empty() -> Array:
	var snap := []
	for r in range(ROWS):
		var row := []
		for c in range(COLS):
			row.append(AIBrain.EMPTY)
		snap.append(row)
	return snap

func _initialize() -> void:
	# --- 2-chain setup -------------------------------------------------------
	# Swap (row 9, cols 2<->3) turns column 2 into a vertical R triple (chain 1).
	# Clearing it drops a G from row 8 into row 11 col 2, completing G,G,G across
	# row 11 cols 1-3 (chain 2).
	var s := _make_empty()
	s[11][1] = G
	s[8][2] = G
	s[9][2] = Y
	s[10][2] = R
	s[11][2] = R
	s[9][3] = R
	s[10][3] = B
	s[11][3] = G

	var outcome := AIBrain.simulate_swap(s, 9, 2)
	assert(outcome["chain"] == 2)

	var best := AIBrain.best_swap_chain(s)
	assert(not best.is_empty())
	assert(best["row"] == 9 and best["col"] == 2)

	# A chain move must outscore a plain single match.
	var single := _make_empty()
	single[11] = [R, R, Y, R, AIBrain.EMPTY, AIBrain.EMPTY]
	var single_best := AIBrain.best_swap_chain(single)
	assert(not single_best.is_empty())
	assert(AIBrain.simulate_swap(single, single_best["row"], single_best["col"])["chain"] == 1)
	assert(best["score"] > single_best["score"])

	# Empty board: nothing to do.
	assert(AIBrain.best_swap_chain(_make_empty()).is_empty())

	# Expert preset really enables the chain brain.
	assert(AIBrain.DIFFICULTIES["expert"]["chains"] == true)

	print("ALL TESTS PASSED")
	quit()
