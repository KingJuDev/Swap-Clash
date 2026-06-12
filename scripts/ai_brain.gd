class_name AIBrain
extends RefCounted

# Pure, board-independent decision logic for the CPU player.
#
# Works on a "snapshot": a 2D array (rows x cols) where each cell is:
#   -1  -> empty
#   -2  -> blocked (a non-IDLE block or garbage; cannot be swapped or matched)
#   >=0 -> the color id of an IDLE block
#
# All functions are static so they can be unit-tested without a live Board.

const EMPTY := -1
const BLOCKED := -2

# Difficulty presets: how often the AI re-plans, how fast it taps the cursor,
# and how often it deliberately picks a worse move. Tuning values.
const DIFFICULTIES := {
	"facile": {"think_interval": 0.55, "move_period": 0.16, "mistake_chance": 0.35},
	"moyen": {"think_interval": 0.30, "move_period": 0.10, "mistake_chance": 0.15},
	"difficile": {"think_interval": 0.16, "move_period": 0.06, "mistake_chance": 0.04},
}

static func difficulty(name: String) -> Dictionary:
	return DIFFICULTIES.get(name, DIFFICULTIES["moyen"])

# Returns { "row": int, "col": int, "score": int } for the best horizontal swap
# (col = left column under the 2-wide cursor), or {} if no worthwhile move exists.
static func best_swap(snapshot: Array) -> Dictionary:
	var rows := snapshot.size()
	if rows == 0:
		return {}
	var cols: int = snapshot[0].size()
	var base_adjacency := _adjacency(snapshot)

	var best := {}
	var best_score := 0
	for r in range(rows):
		for c in range(cols - 1):
			var a: int = snapshot[r][c]
			var b: int = snapshot[r][c + 1]
			if not _swappable(a) or not _swappable(b) or a == b:
				continue
			var sim := _swapped(snapshot, r, c)
			var matched := _count_matched(sim)
			var score: int
			if matched > 0:
				score = 1000 + 100 * matched
			else:
				score = (_adjacency(sim) - base_adjacency) * 10
			if score > best_score:
				best_score = score
				best = {"row": r, "col": c, "score": score}
	return best

static func _swappable(cell: int) -> bool:
	return cell == EMPTY or cell >= 0

static func _swapped(snapshot: Array, r: int, c: int) -> Array:
	var copy := []
	for row in snapshot:
		copy.append(row.duplicate())
	var tmp: int = copy[r][c]
	copy[r][c] = copy[r][c + 1]
	copy[r][c + 1] = tmp
	return copy

# Number of grid cells that belong to a horizontal or vertical run of >= 3
# same-colored idle blocks. Mirrors board.gd's _find_matches.
static func _count_matched(snapshot: Array) -> int:
	var rows := snapshot.size()
	var cols: int = snapshot[0].size()
	var matched := {}

	for r in range(rows):
		var c := 0
		while c < cols:
			var color: int = snapshot[r][c]
			if color < 0:
				c += 1
				continue
			var end := c + 1
			while end < cols and snapshot[r][end] == color:
				end += 1
			if end - c >= 3:
				for cc in range(c, end):
					matched[Vector2i(cc, r)] = true
			c = end

	for c in range(cols):
		var r := 0
		while r < rows:
			var color: int = snapshot[r][c]
			if color < 0:
				r += 1
				continue
			var end := r + 1
			while end < rows and snapshot[end][c] == color:
				end += 1
			if end - r >= 3:
				for rr in range(r, end):
					matched[Vector2i(c, rr)] = true
			r = end

	return matched.size()

# Count of orthogonally adjacent same-color idle pairs (a proxy for "almost
# matches" the AI is setting up).
static func _adjacency(snapshot: Array) -> int:
	var rows := snapshot.size()
	var cols: int = snapshot[0].size()
	var count := 0
	for r in range(rows):
		for c in range(cols):
			var color: int = snapshot[r][c]
			if color < 0:
				continue
			if c + 1 < cols and snapshot[r][c + 1] == color:
				count += 1
			if r + 1 < rows and snapshot[r + 1][c] == color:
				count += 1
	return count
