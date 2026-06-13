extends SceneTree

const ROWS := 12
const COLS := 6

func _empty() -> Array:
	var snap := []
	for r in range(ROWS):
		var row := []
		for c in range(COLS):
			row.append(AIBrain.EMPTY)
		snap.append(row)
	return snap

func _initialize() -> void:
	# Two available matches: one (row 11, cols 0-2) sits right under a garbage
	# cell at (col 0, row 10) and would shatter it; the other (row 9, cols 2-4)
	# touches no garbage. The AI must prefer the garbage-clearing one.
	var s := _empty()
	s[10][0] = AIBrain.GARBAGE
	s[11] = [0, 0, 1, 0, 3, 4]        # swap (11,2) -> 0,0,0 next to garbage
	s[9] = [AIBrain.EMPTY, AIBrain.EMPTY, 0, 0, 1, 0]  # swap (9,4) -> 0,0,0, no garbage

	var best := AIBrain.best_swap(s)
	assert(not best.is_empty())
	assert(best["row"] == 11 and best["col"] == 2)

	# simulate_swap reports the garbage it shatters.
	var pos := _empty()
	pos[10][0] = AIBrain.GARBAGE
	pos[11] = [0, 0, 1, 0, 3, 4]
	var pos_out := AIBrain.simulate_swap(pos, 11, 2)
	assert(pos_out["chain"] >= 1)
	assert(pos_out["garbage"] >= 1)

	var neg := _empty()
	neg[8][5] = AIBrain.GARBAGE      # garbage far from the match
	neg[11] = [0, 0, 1, 0, 3, 4]
	var neg_out := AIBrain.simulate_swap(neg, 11, 2)
	assert(neg_out["chain"] >= 1)
	assert(neg_out["garbage"] == 0)

	# The chain brain (Expert) also values garbage clearing: same move scores
	# higher when it shatters garbage.
	var bc_pos := AIBrain.best_swap_chain(pos)
	var bc_neg := AIBrain.best_swap_chain(neg)
	assert(bc_pos["row"] == 11 and bc_pos["col"] == 2)
	assert(bc_pos["score"] > bc_neg["score"])

	print("ALL TESTS PASSED")
	quit()
