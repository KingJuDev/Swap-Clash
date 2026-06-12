class_name AIController
extends RefCounted

# Drives a Board as the CPU player by producing "virtual button" presses that
# board.gd reads when its input_source is "ai". Decisions come from AIBrain;
# this class only handles timing and turning a target into cursor taps so the
# AI feels human and stays beatable.

var difficulty: Dictionary
var buttons := {
	"left": false, "right": false, "up": false, "down": false,
	"swap": false, "fast_rise": false,
}

var _think_timer := 0.0
var _move_timer := 0.0
var _plan := {} # { "row": int, "col": int } or empty

func _init(difficulty_name: String = "moyen") -> void:
	difficulty = AIBrain.difficulty(difficulty_name)

func update(board: Object, delta: float) -> void:
	for key in buttons:
		buttons[key] = false

	_think_timer -= delta
	if _plan.is_empty() or _think_timer <= 0.0:
		_replan(board)
		_think_timer = difficulty["think_interval"]

	if _plan.is_empty():
		return

	_move_timer -= delta
	if _move_timer > 0.0:
		return
	_move_timer = difficulty["move_period"]

	var cursor: Vector2i = board.cursor_pos
	if cursor.y > _plan["row"]:
		buttons["up"] = true
	elif cursor.y < _plan["row"]:
		buttons["down"] = true
	elif cursor.x > _plan["col"]:
		buttons["left"] = true
	elif cursor.x < _plan["col"]:
		buttons["right"] = true
	else:
		buttons["swap"] = true
		_plan = {}

func _replan(board: Object) -> void:
	var snapshot := _snapshot(board)
	if randf() < difficulty["mistake_chance"]:
		_plan = _random_legal(snapshot)
	else:
		var swap := AIBrain.best_swap(snapshot)
		_plan = {"row": swap["row"], "col": swap["col"]} if not swap.is_empty() else {}

func _snapshot(board: Object) -> Array:
	var snapshot := []
	for row in range(board.VISIBLE_ROWS):
		var cells := []
		for col in range(board.GRID_WIDTH):
			var cell: Variant = board.grid[row][col]
			if cell is Block and cell.state == Block.State.IDLE:
				cells.append(cell.color_id)
			elif cell == null:
				cells.append(AIBrain.EMPTY)
			else:
				cells.append(AIBrain.BLOCKED)
		snapshot.append(cells)
	return snapshot

func _random_legal(snapshot: Array) -> Dictionary:
	var legal := []
	for r in range(snapshot.size()):
		var cols: int = snapshot[r].size()
		for c in range(cols - 1):
			var a: int = snapshot[r][c]
			var b: int = snapshot[r][c + 1]
			if AIBrain._swappable(a) and AIBrain._swappable(b) and a != b:
				legal.append({"row": r, "col": c})
	if legal.is_empty():
		return {}
	return legal[randi() % legal.size()]
