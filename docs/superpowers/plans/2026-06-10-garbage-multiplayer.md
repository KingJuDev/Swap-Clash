# Garbage Blocks + Local 2-Player Multiplayer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add grey "garbage" blocks (sent via combos/chains, with a counter mechanic) and a
local 2-player mode (2 gamepads, 2 boards side by side) to the existing Tetris-Attack-style
puzzle engine.

**Architecture:** Extend `board.gd` with a new `GarbageBlock` grid citizen (multi-cell,
shatters from the bottom when touched by a match, falls as a unit), a per-board garbage
queue with telegraph + counter, and gamepad-based input. A new `Match.tscn`/`match.gd`
instantiates two `Board`s, routes garbage between them, and handles win/lose.

**Tech Stack:** Godot 4.6 / GDScript. Tests are headless `SceneTree` scripts under `tests/`,
run via `godot --headless --script tests/<file>.gd`.

**Spec:** `docs/superpowers/specs/2026-06-10-garbage-multiplayer-design.md`

**Test runner pattern** (used in every "Run test" step, replace `<file>`):

```bash
pkill -f "Godot.app/Contents/MacOS/Godot" 2>/dev/null; sleep 1; cd "/Users/floriojulien/Code/Swap & Clash" && (/Users/floriojulien/Downloads/Godot.app/Contents/MacOS/Godot --headless --script tests/<file>.gd > /tmp/test_out.log 2>&1 &) ; sleep 8; pkill -f "Godot.app/Contents/MacOS/Godot"; sleep 1; cat /tmp/test_out.log
```

Expected: the log ends with `ALL TESTS PASSED` and contains no `SCRIPT ERROR` / `Invalid`
lines.

---

### Task 1: Garbage power formula

**Files:**
- Modify: `scripts/board.gd` (add function after `_score_for`, around line 220)
- Test: `tests/test_garbage_power.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
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
```

- [ ] **Step 2: Run test to verify it fails**

Run the test runner pattern above with `<file>` = `test_garbage_power`.
Expected: `SCRIPT ERROR` — `_garbage_power_for` does not exist (Invalid call / nonexistent
function).

- [ ] **Step 3: Implement `_garbage_power_for`**

Add this function to `scripts/board.gd`, right after `_score_for` (after line 220):

```gdscript
func _garbage_power_for(combo_size: int, chain: int) -> int:
	if chain >= 2:
		var height := min(chain - 1, 12)
		return 6 * height
	if combo_size >= 4:
		return min(combo_size - 1, 6)
	return 0
```

- [ ] **Step 4: Run test to verify it passes**

Run the test runner pattern with `<file>` = `test_garbage_power`.
Expected: `ALL TESTS PASSED`.

- [ ] **Step 5: Commit**

```bash
git add scripts/board.gd tests/test_garbage_power.gd
git commit -m "Add garbage power formula for combos and chains"
```

---

### Task 2: Garbage shape from power

**Files:**
- Modify: `scripts/board.gd` (add constant near top, function after `_garbage_power_for`)
- Test: `tests/test_garbage_shape.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends SceneTree

const BoardScene := preload("res://scenes/Board.tscn")

var _board: Variant = null

func _initialize() -> void:
	_board = BoardScene.instantiate()
	get_root().add_child(_board)

func _process(_delta: float) -> bool:
	var board: Variant = _board

	assert(board.MAX_GARBAGE_HEIGHT == 11)

	assert(board._garbage_shape_for_power(0) == {"height": 0, "width": 0})
	assert(board._garbage_shape_for_power(3) == {"height": 1, "width": 3})
	assert(board._garbage_shape_for_power(6) == {"height": 1, "width": 6})
	assert(board._garbage_shape_for_power(7) == {"height": 2, "width": 6})
	assert(board._garbage_shape_for_power(12) == {"height": 2, "width": 6})
	assert(board._garbage_shape_for_power(13) == {"height": 3, "width": 6})
	assert(board._garbage_shape_for_power(72) == {"height": 11, "width": 6})

	print("ALL TESTS PASSED")
	quit()
	return true
```

- [ ] **Step 2: Run test to verify it fails**

Run the test runner pattern with `<file>` = `test_garbage_shape`.
Expected: `SCRIPT ERROR` — `MAX_GARBAGE_HEIGHT` / `_garbage_shape_for_power` do not exist.

- [ ] **Step 3: Implement the constant and function**

Add this constant to `scripts/board.gd` near the other constants, right after line 23
(`const MOVE_REPEAT_RATE := 0.06`):

```gdscript
const TELEGRAPH_DURATION := 2.0
const MAX_GARBAGE_HEIGHT := VISIBLE_ROWS - 1
```

Add this function right after `_garbage_power_for`:

```gdscript
func _garbage_shape_for_power(power: int) -> Dictionary:
	if power <= 0:
		return {"height": 0, "width": 0}
	if power <= GRID_WIDTH:
		return {"height": 1, "width": power}
	var height := int(ceil(power / float(GRID_WIDTH)))
	height = min(height, MAX_GARBAGE_HEIGHT)
	return {"height": height, "width": GRID_WIDTH}
```

- [ ] **Step 4: Run test to verify it passes**

Run the test runner pattern with `<file>` = `test_garbage_shape`.
Expected: `ALL TESTS PASSED`.

- [ ] **Step 5: Commit**

```bash
git add scripts/board.gd tests/test_garbage_shape.gd
git commit -m "Add garbage shape conversion (power -> rectangle)"
```

---

### Task 3: GarbageBlock scene & script

**Files:**
- Create: `scripts/garbage_block.gd`
- Create: `scenes/GarbageBlock.tscn`
- Test: `tests/test_garbage_block.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends SceneTree

const GarbageBlockScene := preload("res://scenes/GarbageBlock.tscn")

var _g: Variant = null

func _initialize() -> void:
	_g = GarbageBlockScene.instantiate()
	get_root().add_child(_g)

func _process(_delta: float) -> bool:
	var g: Variant = _g

	g.setup(3, 2, 64)
	assert(g.width == 3)
	assert(g.height == 2)
	assert(g.size == Vector2(192, 128))
	assert(g.color == Color(0.4, 0.4, 0.4))
	assert(g.state == GarbageBlock.State.IDLE)

	g.shrink_to(1, 64)
	assert(g.height == 1)
	assert(g.size == Vector2(192, 64))

	print("ALL TESTS PASSED")
	quit()
	return true
```

- [ ] **Step 2: Run test to verify it fails**

Run the test runner pattern with `<file>` = `test_garbage_block`.
Expected: `ERROR: Failed to load script` — `res://scenes/GarbageBlock.tscn` does not exist.

- [ ] **Step 3: Create `scripts/garbage_block.gd`**

```gdscript
class_name GarbageBlock
extends ColorRect

enum State { IDLE, FALLING, FLASHING }

const GARBAGE_COLOR := Color(0.4, 0.4, 0.4)
const GRID_LINE_COLOR := Color(0.25, 0.25, 0.25)

var width: int = 1
var height: int = 1
var origin: Vector2i = Vector2i.ZERO
var state: State = State.IDLE

var _cell_size: int = 64

func setup(w: int, h: int, cell_size: int) -> void:
	width = w
	height = h
	_cell_size = cell_size
	color = GARBAGE_COLOR
	size = Vector2(w * cell_size, h * cell_size)
	queue_redraw()

func _draw() -> void:
	for c in range(1, width):
		draw_line(Vector2(c * _cell_size, 0), Vector2(c * _cell_size, height * _cell_size), GRID_LINE_COLOR, 1.0)
	for r in range(1, height):
		draw_line(Vector2(0, r * _cell_size), Vector2(width * _cell_size, r * _cell_size), GRID_LINE_COLOR, 1.0)

func play_fall(target_pos: Vector2, duration: float) -> void:
	state = State.FALLING
	var tween := create_tween()
	tween.tween_property(self, "position", target_pos, duration)
	tween.finished.connect(func(): state = State.IDLE)

func play_match_flash() -> void:
	state = State.FLASHING
	var tween := create_tween()
	tween.set_loops(4)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0.25), 0.08)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.08)

func shrink_to(new_height: int, cell_size: int) -> void:
	height = new_height
	_cell_size = cell_size
	size = Vector2(width * cell_size, height * cell_size)
	state = State.IDLE
	queue_redraw()
```

- [ ] **Step 4: Create `scenes/GarbageBlock.tscn`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/garbage_block.gd" id="1"]

[node name="GarbageBlock" type="ColorRect"]
offset_right = 64.0
offset_bottom = 64.0
mouse_filter = 2
color = Color(0.4, 0.4, 0.4, 1)
script = ExtResource("1")
```

- [ ] **Step 5: Run test to verify it passes**

Run the test runner pattern with `<file>` = `test_garbage_block`.
Expected: `ALL TESTS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add scripts/garbage_block.gd scenes/GarbageBlock.tscn tests/test_garbage_block.gd
git commit -m "Add GarbageBlock scene and script"
```

---

### Task 4: Garbage as a grid citizen (spawn, visuals, rise, match-scan guards)

This task makes `grid[row][col]` able to hold a `GarbageBlock` reference (shared across all
cells of its footprint) without breaking existing logic.

**Files:**
- Modify: `scripts/board.gd`
  - Add preload near line 7
  - Add `_spawn_garbage_block` (new function)
  - Modify `_find_matches` (lines 181-214) — guard against non-`Block` cells
  - Modify `_generate_row` (lines 222-238) — guard against non-`Block` cells
  - Modify `_do_rise_step` (lines 240-256) — handle `GarbageBlock` cells
  - Modify `_update_visuals` (lines 273-279) — handle `GarbageBlock` cells
- Test: `tests/test_garbage_grid.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends SceneTree

const BoardScene := preload("res://scenes/Board.tscn")

var _board: Variant = null

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

	# Spawn a 2x2 garbage block at columns 1-2, rows 9-10.
	var g: Variant = board._spawn_garbage_block(Vector2i(1, 9), 2, 2)
	assert(g.width == 2 and g.height == 2)
	assert(board.grid[9][1] == g and board.grid[9][2] == g)
	assert(board.grid[10][1] == g and board.grid[10][2] == g)
	assert(g.position == board._cell_position(1, 9))

	# _find_matches must not crash when garbage cells are present, and must
	# not consider them part of any match.
	for col in range(3, 6):
		board.grid[11][col] = board._spawn_block(0, 11, col)
	var matches: Array = board._find_matches()
	assert(matches.size() == 3)

	# A rise step must shift the garbage block's origin up by 1 without error.
	board._do_rise_step()
	assert(board.game_over_flag == false)
	assert(g.origin == Vector2i(1, 8))
	assert(board.grid[8][1] == g and board.grid[8][2] == g)
	assert(board.grid[9][1] == g and board.grid[9][2] == g)

	print("ALL TESTS PASSED")
	quit()
	return true
```

- [ ] **Step 2: Run test to verify it fails**

Run the test runner pattern with `<file>` = `test_garbage_grid`.
Expected: `SCRIPT ERROR` — `_spawn_garbage_block` does not exist.

- [ ] **Step 3: Add the `GarbageBlock` preload**

In `scripts/board.gd`, change line 7 from:

```gdscript
const BlockScene := preload("res://scenes/Block.tscn")
```

to:

```gdscript
const BlockScene := preload("res://scenes/Block.tscn")
const GarbageBlockScene := preload("res://scenes/GarbageBlock.tscn")
```

- [ ] **Step 4: Add `_spawn_garbage_block`**

Add this function right after `_spawn_block` (after line 268):

```gdscript
func _spawn_garbage_block(origin: Vector2i, width: int, height: int) -> GarbageBlock:
	var g := GarbageBlockScene.instantiate() as GarbageBlock
	add_child(g)
	g.setup(width, height, CELL_SIZE)
	g.origin = origin
	g.position = _cell_position(origin.x, origin.y)
	for col in range(origin.x, origin.x + width):
		for row in range(origin.y, origin.y + height):
			grid[row][col] = g
	return g
```

- [ ] **Step 5: Guard `_find_matches` against non-`Block` cells**

Replace the row-scan loop (lines 184-197):

```gdscript
	for row in range(VISIBLE_ROWS):
		var col := 0
		while col < GRID_WIDTH:
			var b: Variant = grid[row][col]
			if b == null:
				col += 1
				continue
			var run_end := col + 1
			while run_end < GRID_WIDTH and grid[row][run_end] != null and grid[row][run_end].color_id == b.color_id:
				run_end += 1
			if run_end - col >= 3:
				for c in range(col, run_end):
					matched[Vector2i(c, row)] = true
			col = run_end
```

with:

```gdscript
	for row in range(VISIBLE_ROWS):
		var col := 0
		while col < GRID_WIDTH:
			var b: Variant = grid[row][col]
			if not (b is Block):
				col += 1
				continue
			var run_end := col + 1
			while run_end < GRID_WIDTH and grid[row][run_end] is Block and grid[row][run_end].color_id == b.color_id:
				run_end += 1
			if run_end - col >= 3:
				for c in range(col, run_end):
					matched[Vector2i(c, row)] = true
			col = run_end
```

Replace the column-scan loop (lines 199-212):

```gdscript
	for col in range(GRID_WIDTH):
		var row := 0
		while row < VISIBLE_ROWS:
			var b: Variant = grid[row][col]
			if b == null:
				row += 1
				continue
			var run_end := row + 1
			while run_end < VISIBLE_ROWS and grid[run_end][col] != null and grid[run_end][col].color_id == b.color_id:
				run_end += 1
			if run_end - row >= 3:
				for r in range(row, run_end):
					matched[Vector2i(col, r)] = true
			row = run_end
```

with:

```gdscript
	for col in range(GRID_WIDTH):
		var row := 0
		while row < VISIBLE_ROWS:
			var b: Variant = grid[row][col]
			if not (b is Block):
				row += 1
				continue
			var run_end := row + 1
			while run_end < VISIBLE_ROWS and grid[run_end][col] is Block and grid[run_end][col].color_id == b.color_id:
				run_end += 1
			if run_end - row >= 3:
				for r in range(row, run_end):
					matched[Vector2i(col, r)] = true
			row = run_end
```

- [ ] **Step 6: Guard `_generate_row` against non-`Block` cells**

In `_generate_row` (lines 222-238), replace:

```gdscript
		if row_index >= 2:
			var above1: Variant = grid[row_index - 1][col]
			var above2: Variant = grid[row_index - 2][col]
			if above1 != null and above2 != null and above1.color_id == above2.color_id:
				forbidden.append(above1.color_id)
```

with:

```gdscript
		if row_index >= 2:
			var above1: Variant = grid[row_index - 1][col]
			var above2: Variant = grid[row_index - 2][col]
			if above1 is Block and above2 is Block and above1.color_id == above2.color_id:
				forbidden.append(above1.color_id)
```

- [ ] **Step 7: Handle `GarbageBlock` in `_do_rise_step`**

Replace the row-shift loop in `_do_rise_step` (lines 246-251):

```gdscript
	for row in range(TOTAL_ROWS - 1):
		grid[row] = grid[row + 1]
		for col in range(GRID_WIDTH):
			if grid[row][col] != null:
				grid[row][col].grid_pos = Vector2i(col, row)
```

with:

```gdscript
	var shifted_garbage := {}
	for row in range(TOTAL_ROWS - 1):
		grid[row] = grid[row + 1]
		for col in range(GRID_WIDTH):
			var cell: Variant = grid[row][col]
			if cell is Block:
				cell.grid_pos = Vector2i(col, row)
			elif cell is GarbageBlock and not shifted_garbage.has(cell):
				shifted_garbage[cell] = true
				cell.origin = Vector2i(cell.origin.x, cell.origin.y - 1)
```

- [ ] **Step 8: Handle `GarbageBlock` in `_update_visuals`**

Replace `_update_visuals` (lines 273-279):

```gdscript
func _update_visuals() -> void:
	for row in range(TOTAL_ROWS):
		for col in range(GRID_WIDTH):
			var b: Variant = grid[row][col]
			if b != null and b.state == Block.State.IDLE:
				b.position = _cell_position(b.grid_pos.x, b.grid_pos.y)
	cursor_node.position = _cell_position(cursor_pos.x, cursor_pos.y)
```

with:

```gdscript
func _update_visuals() -> void:
	for row in range(TOTAL_ROWS):
		for col in range(GRID_WIDTH):
			var b: Variant = grid[row][col]
			if b == null:
				continue
			if b is Block and b.state == Block.State.IDLE:
				b.position = _cell_position(b.grid_pos.x, b.grid_pos.y)
			elif b is GarbageBlock and b.state == GarbageBlock.State.IDLE:
				b.position = _cell_position(b.origin.x, b.origin.y)
	cursor_node.position = _cell_position(cursor_pos.x, cursor_pos.y)
```

- [ ] **Step 9: Run test to verify it passes**

Run the test runner pattern with `<file>` = `test_garbage_grid`.
Expected: `ALL TESTS PASSED`, with no `SCRIPT ERROR` lines anywhere in the log.

- [ ] **Step 10: Commit**

```bash
git add scripts/board.gd tests/test_garbage_grid.gd
git commit -m "Make GarbageBlock a grid citizen (spawn, rise, visuals, match-scan guards)"
```

---

### Task 5: Gravity for multi-cell garbage blocks

**Files:**
- Modify: `scripts/board.gd` — replace `_apply_gravity` (lines 163-179), add 2 helper
  functions
- Test: `tests/test_garbage_gravity.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends SceneTree

const BoardScene := preload("res://scenes/Board.tscn")

var _board: Variant = null

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

	# Garbage 2x1 floating at row 8, columns 2-3. Empty below it down to the floor (row 11).
	var g: Variant = board._spawn_garbage_block(Vector2i(2, 8), 2, 1)

	# A normal block sits above the garbage, in column 2, with empty space between.
	var b: Variant = board._spawn_block(0, 5, 2)
	board.grid[5][2] = b

	board._apply_gravity()

	# Garbage falls to the floor (row 11).
	assert(g.origin == Vector2i(2, 11))
	assert(board.grid[11][2] == g and board.grid[11][3] == g)

	# The block above falls to rest just above the garbage (row 10).
	assert(b.grid_pos == Vector2i(2, 10))
	assert(board.grid[10][2] == b)

	print("ALL TESTS PASSED")
	quit()
	return true
```

- [ ] **Step 2: Run test to verify it fails**

Run the test runner pattern with `<file>` = `test_garbage_gravity`.
Expected: assertion failure — `g.origin == Vector2i(2, 8)` (garbage doesn't fall) or a
`SCRIPT ERROR` from the current `_apply_gravity` treating the garbage cells as `Block`.

- [ ] **Step 3: Replace `_apply_gravity`**

Replace `_apply_gravity` (lines 163-179):

```gdscript
func _apply_gravity() -> void:
	var any_falling := false
	for col in range(GRID_WIDTH):
		var write_row := VISIBLE_ROWS - 1
		for row in range(VISIBLE_ROWS - 1, -1, -1):
			if grid[row][col] != null:
				if write_row != row:
					var b: Variant = grid[row][col]
					grid[write_row][col] = b
					grid[row][col] = null
					b.grid_pos = Vector2i(col, write_row)
					var dist := write_row - row
					b.play_fall(_cell_position(col, write_row), FALL_DURATION_PER_CELL * dist)
					any_falling = true
				write_row -= 1
	if any_falling:
		await get_tree().create_timer(FALL_DURATION_PER_CELL * VISIBLE_ROWS).timeout
```

with:

```gdscript
func _apply_gravity() -> void:
	var start_pos := {}
	var any_moved := true
	while any_moved:
		any_moved = false

		# Compact normal blocks within each column, segment by segment
		# (a GarbageBlock cell acts as a solid floor for the segment above it).
		for col in range(GRID_WIDTH):
			var write_row := VISIBLE_ROWS - 1
			for row in range(VISIBLE_ROWS - 1, -1, -1):
				var cell: Variant = grid[row][col]
				if cell is GarbageBlock:
					write_row = row - 1
					continue
				if cell != null:
					if not start_pos.has(cell):
						start_pos[cell] = cell.grid_pos
					if write_row != row:
						grid[write_row][col] = cell
						grid[row][col] = null
						cell.grid_pos = Vector2i(col, write_row)
						any_moved = true
					write_row -= 1

		# Move garbage blocks down as units, by the smallest empty gap under
		# any of the columns they cover.
		var processed := {}
		for row in range(VISIBLE_ROWS - 1, -1, -1):
			for col in range(GRID_WIDTH):
				var cell: Variant = grid[row][col]
				if cell is GarbageBlock and not processed.has(cell):
					processed[cell] = true
					if not start_pos.has(cell):
						start_pos[cell] = cell.origin
					var drop := _garbage_drop_distance(cell)
					if drop > 0:
						_move_garbage_block(cell, drop)
						any_moved = true

	var any_falling := false
	for cell in start_pos.keys():
		var start: Vector2i = start_pos[cell]
		var end: Vector2i = cell.grid_pos if cell is Block else cell.origin
		var dist := end.y - start.y
		if dist > 0:
			cell.play_fall(_cell_position(end.x, end.y), FALL_DURATION_PER_CELL * dist)
			any_falling = true
	if any_falling:
		await get_tree().create_timer(FALL_DURATION_PER_CELL * VISIBLE_ROWS).timeout

func _garbage_drop_distance(g: GarbageBlock) -> int:
	var bottom_row := g.origin.y + g.height - 1
	var max_drop := VISIBLE_ROWS
	for col in range(g.origin.x, g.origin.x + g.width):
		var empty_below := 0
		var row := bottom_row + 1
		while row < VISIBLE_ROWS and grid[row][col] == null:
			empty_below += 1
			row += 1
		max_drop = min(max_drop, empty_below)
	return max(max_drop, 0)

func _move_garbage_block(g: GarbageBlock, drop: int) -> void:
	for col in range(g.origin.x, g.origin.x + g.width):
		for row in range(g.origin.y, g.origin.y + g.height):
			grid[row][col] = null
	g.origin.y += drop
	for col in range(g.origin.x, g.origin.x + g.width):
		for row in range(g.origin.y, g.origin.y + g.height):
			grid[row][col] = g
```

- [ ] **Step 4: Run test to verify it passes**

Run the test runner pattern with `<file>` = `test_garbage_gravity`.
Expected: `ALL TESTS PASSED`.

- [ ] **Step 5: Commit**

```bash
git add scripts/board.gd tests/test_garbage_gravity.gd
git commit -m "Extend gravity to move multi-cell garbage blocks as units"
```

---

### Task 6: Garbage shatter on adjacent match + garbage_sent signal

**Files:**
- Modify: `scripts/board.gd`
  - Add `signal garbage_sent(power: int)` near the other signals (after line 5)
  - Replace `_resolve_matches` (lines 135-161)
  - Add `_send_garbage` and `_shatter_garbage_bottom_row`
- Test: `tests/test_garbage_shatter.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends SceneTree

const BoardScene := preload("res://scenes/Board.tscn")

var _board: Variant = null
var _garbage: Variant = null
var _emitted_power := -1
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

func _process(_delta: float) -> bool:
	var board: Variant = _board

	if not _started:
		_started = true
		seed(42)
		_clear(board)

		# Garbage 3x2 at columns 0-2, rows 9-10.
		_garbage = board._spawn_garbage_block(Vector2i(0, 9), 3, 2)

		# Horizontal 3-match of color 0 at row 10, columns 3-5.
		# Cell (3,10) is adjacent to garbage cell (2,10) -> garbage must shatter.
		for col in range(3, 6):
			board.grid[10][col] = board._spawn_block(0, 10, col)

		board.garbage_sent.connect(func(power: int): _emitted_power = power)
		board._resolve_matches()

		# garbage_sent must fire synchronously (before the first await):
		# combo of 3, no chain bonus -> power 0, nothing emitted yet.
		assert(_emitted_power == -1)
		return false

	_frame += 1
	if _frame < 180:
		return false

	# The garbage block lost its bottom row: height shrank from 2 to 1.
	assert(_garbage.height == 1)
	assert(_garbage.width == 3)

	# Either the 3 freed panels remain (no further chain) or they matched
	# again and were cleared (chain) - both are valid outcomes.
	var total_blocks := 0
	for row in range(board.VISIBLE_ROWS):
		for col in range(board.GRID_WIDTH):
			if board.grid[row][col] is Block:
				total_blocks += 1
	assert(total_blocks == 0 or total_blocks == 3)

	print("ALL TESTS PASSED")
	quit()
	return true
```

- [ ] **Step 2: Run test to verify it fails**

Run the test runner pattern with `<file>` = `test_garbage_shatter`.
Expected: `SCRIPT ERROR` — `garbage_sent` signal does not exist on `Board`.

- [ ] **Step 3: Add the `garbage_sent` signal**

In `scripts/board.gd`, change line 5 from:

```gdscript
signal game_over
```

to:

```gdscript
signal game_over
signal garbage_sent(power: int)
```

- [ ] **Step 4: Replace `_resolve_matches` and add helper functions**

Replace `_resolve_matches` (lines 136-162):

```gdscript
func _resolve_matches() -> void:
	var matches := _find_matches()
	if matches.is_empty():
		chain_count = 0
		return

	chain_count += 1
	score += _score_for(matches.size(), chain_count)
	score_changed.emit(score)
	if chain_count > 1:
		chain_updated.emit(chain_count)

	for pos in matches:
		grid[pos.y][pos.x].play_match_flash()
	await get_tree().create_timer(FLASH_DURATION).timeout

	for pos in matches:
		grid[pos.y][pos.x].play_clear()
	await get_tree().create_timer(CLEAR_DURATION).timeout

	for pos in matches:
		var b: Variant = grid[pos.y][pos.x]
		grid[pos.y][pos.x] = null
		b.queue_free()

	await _apply_gravity()
	await _resolve_matches()
```

with:

```gdscript
func _resolve_matches() -> void:
	var matches := _find_matches()
	if matches.is_empty():
		chain_count = 0
		return

	chain_count += 1
	var combo_size := matches.size()
	score += _score_for(combo_size, chain_count)
	score_changed.emit(score)
	if chain_count > 1:
		chain_updated.emit(chain_count)

	var power := _garbage_power_for(combo_size, chain_count)
	if power > 0:
		_send_garbage(power)

	var to_shatter := {}
	for pos in matches:
		for dir in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var n := pos + dir
			if n.x < 0 or n.x >= GRID_WIDTH or n.y < 0 or n.y >= VISIBLE_ROWS:
				continue
			var cell: Variant = grid[n.y][n.x]
			if cell is GarbageBlock:
				to_shatter[cell] = true

	for pos in matches:
		grid[pos.y][pos.x].play_match_flash()
	for g in to_shatter.keys():
		g.play_match_flash()
	await get_tree().create_timer(FLASH_DURATION).timeout

	for pos in matches:
		grid[pos.y][pos.x].play_clear()
	await get_tree().create_timer(CLEAR_DURATION).timeout

	for pos in matches:
		var b: Variant = grid[pos.y][pos.x]
		grid[pos.y][pos.x] = null
		b.queue_free()

	for g in to_shatter.keys():
		_shatter_garbage_bottom_row(g)

	await _apply_gravity()
	await _resolve_matches()

func _send_garbage(power: int) -> void:
	garbage_sent.emit(power)

func _shatter_garbage_bottom_row(g: GarbageBlock) -> void:
	var bottom_row := g.origin.y + g.height - 1
	for col in range(g.origin.x, g.origin.x + g.width):
		grid[bottom_row][col] = _spawn_block(randi() % NUM_COLORS, bottom_row, col)
	g.height -= 1
	if g.height <= 0:
		g.queue_free()
	else:
		g.shrink_to(g.height, CELL_SIZE)
```

Note: `_send_garbage` is a thin placeholder for now — Task 7 upgrades it with the
counter/queue logic.

- [ ] **Step 5: Run test to verify it passes**

Run the test runner pattern with `<file>` = `test_garbage_shatter`.
Expected: `ALL TESTS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add scripts/board.gd tests/test_garbage_shatter.gd
git commit -m "Shatter adjacent garbage blocks on match and emit garbage_sent"
```

---

### Task 7: Garbage queue, telegraph & counter

**Files:**
- Modify: `scripts/board.gd`
  - Add `var pending_garbage: Array = []` near the other state vars (after line 37)
  - Replace `_send_garbage` (added in Task 6)
  - Add `receive_garbage` and `_update_garbage_queue`
  - Call `_update_garbage_queue(delta)` from `_process`
- Test: `tests/test_garbage_queue.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
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
```

- [ ] **Step 2: Run test to verify it fails**

Run the test runner pattern with `<file>` = `test_garbage_queue`.
Expected: `SCRIPT ERROR` — `pending_garbage` / `receive_garbage` do not exist.

- [ ] **Step 3: Add `pending_garbage` state**

In `scripts/board.gd`, change line 37 from:

```gdscript
var game_over_flag := false
```

to:

```gdscript
var game_over_flag := false
var pending_garbage: Array = []
```

- [ ] **Step 4: Replace `_send_garbage` and add `receive_garbage` / `_update_garbage_queue`**

Replace the placeholder `_send_garbage` (added in Task 6):

```gdscript
func _send_garbage(power: int) -> void:
	garbage_sent.emit(power)
```

with:

```gdscript
func _send_garbage(power: int) -> void:
	var remaining := power
	var i := 0
	while remaining > 0 and i < pending_garbage.size():
		var item: Dictionary = pending_garbage[i]
		var cancel: int = min(remaining, item.power)
		item.power -= cancel
		remaining -= cancel
		if item.power <= 0:
			pending_garbage.remove_at(i)
		else:
			pending_garbage[i] = item
			i += 1
	if remaining > 0:
		garbage_sent.emit(remaining)

func receive_garbage(power: int) -> void:
	var shape := _garbage_shape_for_power(power)
	var c0 := randi() % (GRID_WIDTH - shape.width + 1)
	pending_garbage.append({
		"power": power,
		"telegraph_time": TELEGRAPH_DURATION,
		"columns": Vector2i(c0, shape.width),
	})

func _update_garbage_queue(delta: float) -> void:
	for i in range(pending_garbage.size()):
		var item: Dictionary = pending_garbage[i]
		if item.telegraph_time > 0.0:
			item.telegraph_time = max(0.0, item.telegraph_time - delta)
			pending_garbage[i] = item

	if pending_garbage.is_empty():
		return

	var item: Dictionary = pending_garbage[0]
	if item.telegraph_time > 0.0:
		return

	var shape := _garbage_shape_for_power(item.power)
	var c0: int = clampi(item.columns.x, 0, GRID_WIDTH - shape.width)

	for row in range(shape.height):
		for col in range(c0, c0 + shape.width):
			if grid[row][col] != null:
				return

	_spawn_garbage_block(Vector2i(c0, 0), shape.width, shape.height)
	pending_garbage.remove_at(0)
```

- [ ] **Step 5: Call `_update_garbage_queue` from `_process`**

In `scripts/board.gd`, change the start of `_process` (lines 56-59) from:

```gdscript
func _process(delta: float) -> void:
	if game_over_flag:
		return
	_handle_cursor_movement(delta)
```

to:

```gdscript
func _process(delta: float) -> void:
	if game_over_flag:
		return
	_update_garbage_queue(delta)
	_handle_cursor_movement(delta)
```

- [ ] **Step 6: Run test to verify it passes**

Run the test runner pattern with `<file>` = `test_garbage_queue`.
Expected: `ALL TESTS PASSED`.

- [ ] **Step 7: Commit**

```bash
git add scripts/board.gd tests/test_garbage_queue.gd
git commit -m "Add garbage queue with telegraph delay and counter mechanic"
```

---

### Task 8: Gamepad input per board

**Files:**
- Modify: `scripts/board.gd`
  - Add `@export var input_device: int = 0` and `const JOY_AXIS_DEADZONE := 0.5`
  - Rename `_space_was_pressed` to `_swap_was_pressed`
  - Replace input reads in `_process` (swap / fast rise)
  - Replace `_handle_cursor_movement` (lines 77-101) and add `_is_direction_pressed`
- Test: `tests/test_gamepad_input.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends SceneTree

const BoardScene := preload("res://scenes/Board.tscn")

var _board: Variant = null
var _phase := 0
var _frame := 0

func _initialize() -> void:
	_board = BoardScene.instantiate()
	get_root().add_child(_board)

func _process(_delta: float) -> bool:
	var board: Variant = _board

	if _phase == 0:
		assert(board.input_device == 0)
		var start_x: int = board.cursor_pos.x

		var event := InputEventJoypadButton.new()
		event.device = 0
		event.button_index = JOY_BUTTON_DPAD_RIGHT
		event.pressed = true
		Input.parse_input_event(event)

		_phase = 1
		_frame = 0
		return false

	if _phase == 1:
		_frame += 1
		if _frame < 5:
			return false
		assert(board.cursor_pos.x == board.GRID_WIDTH / 2)

		var release := InputEventJoypadButton.new()
		release.device = 0
		release.button_index = JOY_BUTTON_DPAD_RIGHT
		release.pressed = false
		Input.parse_input_event(release)

		# Input on a different device must not move this board's cursor.
		var other := InputEventJoypadButton.new()
		other.device = 1
		other.button_index = JOY_BUTTON_DPAD_LEFT
		other.pressed = true
		Input.parse_input_event(other)

		_phase = 2
		_frame = 0
		return false

	_frame += 1
	if _frame < 5:
		return false

	assert(board.cursor_pos.x == board.GRID_WIDTH / 2)
	print("ALL TESTS PASSED")
	quit()
	return true
```

- [ ] **Step 2: Run test to verify it fails**

Run the test runner pattern with `<file>` = `test_gamepad_input`.
Expected: assertion failure — `board.input_device` does not exist, or the cursor doesn't move
(still keyboard-only).

- [ ] **Step 3: Add `input_device` export and deadzone constant**

In `scripts/board.gd`, change line 25 from:

```gdscript
@onready var cursor_node: ColorRect = $Cursor
```

to:

```gdscript
@export var input_device: int = 0

const JOY_AXIS_DEADZONE := 0.5

@onready var cursor_node: ColorRect = $Cursor
```

- [ ] **Step 4: Rename `_space_was_pressed` and update input reads in `_process`**

In `scripts/board.gd`, change line 39 from:

```gdscript
var _space_was_pressed := false
```

to:

```gdscript
var _swap_was_pressed := false
```

Then change the swap/rise block in `_process` (lines 61-73) from:

```gdscript
	var space_pressed := Input.is_key_pressed(KEY_SPACE)
	if space_pressed and not _space_was_pressed and not is_resolving:
		_try_swap()
	_space_was_pressed = space_pressed

	if not is_resolving:
		var rise_speed := RISE_SPEED_FAST if Input.is_key_pressed(KEY_SHIFT) else RISE_SPEED_NORMAL
		rise_offset += rise_speed * delta
		while rise_offset >= CELL_SIZE:
			rise_offset -= CELL_SIZE
			_do_rise_step()
			if game_over_flag:
				break
```

to:

```gdscript
	var swap_pressed := Input.is_joy_button_pressed(input_device, JOY_BUTTON_A)
	if swap_pressed and not _swap_was_pressed and not is_resolving:
		_try_swap()
	_swap_was_pressed = swap_pressed

	if not is_resolving:
		var rise_speed := RISE_SPEED_FAST if Input.is_joy_button_pressed(input_device, JOY_BUTTON_B) else RISE_SPEED_NORMAL
		rise_offset += rise_speed * delta
		while rise_offset >= CELL_SIZE:
			rise_offset -= CELL_SIZE
			_do_rise_step()
			if game_over_flag:
				break
```

- [ ] **Step 5: Replace `_handle_cursor_movement` with gamepad-based directions**

Replace `_handle_cursor_movement` (lines 77-101):

```gdscript
func _handle_cursor_movement(delta: float) -> void:
	var dirs := {
		KEY_LEFT: Vector2i(-1, 0),
		KEY_RIGHT: Vector2i(1, 0),
		KEY_UP: Vector2i(0, -1),
		KEY_DOWN: Vector2i(0, 1),
	}
	for key in dirs.keys():
		if Input.is_key_pressed(key):
			var prev: float = _key_held_time.get(key, -1.0)
			if prev < 0.0:
				_move_cursor(dirs[key])
				_key_held_time[key] = 0.0
			else:
				var cur: float = prev + delta
				if prev < MOVE_REPEAT_DELAY and cur >= MOVE_REPEAT_DELAY:
					_move_cursor(dirs[key])
				elif prev >= MOVE_REPEAT_DELAY:
					var prev_ticks: float = floor((prev - MOVE_REPEAT_DELAY) / MOVE_REPEAT_RATE)
					var cur_ticks: float = floor((cur - MOVE_REPEAT_DELAY) / MOVE_REPEAT_RATE)
					if cur_ticks > prev_ticks:
						_move_cursor(dirs[key])
				_key_held_time[key] = cur
		else:
			_key_held_time[key] = -1.0
```

with:

```gdscript
func _handle_cursor_movement(delta: float) -> void:
	var dirs := {
		"left": Vector2i(-1, 0),
		"right": Vector2i(1, 0),
		"up": Vector2i(0, -1),
		"down": Vector2i(0, 1),
	}
	for dir_name in dirs.keys():
		if _is_direction_pressed(dir_name):
			var prev: float = _key_held_time.get(dir_name, -1.0)
			if prev < 0.0:
				_move_cursor(dirs[dir_name])
				_key_held_time[dir_name] = 0.0
			else:
				var cur: float = prev + delta
				if prev < MOVE_REPEAT_DELAY and cur >= MOVE_REPEAT_DELAY:
					_move_cursor(dirs[dir_name])
				elif prev >= MOVE_REPEAT_DELAY:
					var prev_ticks: float = floor((prev - MOVE_REPEAT_DELAY) / MOVE_REPEAT_RATE)
					var cur_ticks: float = floor((cur - MOVE_REPEAT_DELAY) / MOVE_REPEAT_RATE)
					if cur_ticks > prev_ticks:
						_move_cursor(dirs[dir_name])
				_key_held_time[dir_name] = cur
		else:
			_key_held_time[dir_name] = -1.0

func _is_direction_pressed(dir_name: String) -> bool:
	match dir_name:
		"left":
			return Input.is_joy_button_pressed(input_device, JOY_BUTTON_DPAD_LEFT) or Input.get_joy_axis(input_device, JOY_AXIS_LEFT_X) < -JOY_AXIS_DEADZONE
		"right":
			return Input.is_joy_button_pressed(input_device, JOY_BUTTON_DPAD_RIGHT) or Input.get_joy_axis(input_device, JOY_AXIS_LEFT_X) > JOY_AXIS_DEADZONE
		"up":
			return Input.is_joy_button_pressed(input_device, JOY_BUTTON_DPAD_UP) or Input.get_joy_axis(input_device, JOY_AXIS_LEFT_Y) < -JOY_AXIS_DEADZONE
		"down":
			return Input.is_joy_button_pressed(input_device, JOY_BUTTON_DPAD_DOWN) or Input.get_joy_axis(input_device, JOY_AXIS_LEFT_Y) > JOY_AXIS_DEADZONE
	return false
```

- [ ] **Step 6: Run test to verify it passes**

Run the test runner pattern with `<file>` = `test_gamepad_input`.
Expected: `ALL TESTS PASSED`.

- [ ] **Step 7: Commit**

```bash
git add scripts/board.gd tests/test_gamepad_input.gd
git commit -m "Replace keyboard input with per-board gamepad input"
```

---

### Task 9: Match scene (2 boards, garbage routing, win/lose)

**Files:**
- Create: `scripts/match.gd`
- Create: `scenes/Match.tscn`
- Test: `tests/test_match.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends SceneTree

const MatchScene := preload("res://scenes/Match.tscn")

var _match: Variant = null

func _initialize() -> void:
	_match = MatchScene.instantiate()
	get_root().add_child(_match)

func _process(_delta: float) -> bool:
	var m: Variant = _match

	# No gamepads connected in headless mode -> waiting screen, boards paused.
	assert(m.waiting_panel.visible == true)
	assert(m.board1.is_processing() == false)
	assert(m.board2.is_processing() == false)
	assert(m.board1.input_device == 0)
	assert(m.board2.input_device == 1)

	# garbage_sent on one board routes to receive_garbage on the other.
	m.board1.garbage_sent.emit(5)
	assert(m.board2.pending_garbage.size() == 1)
	assert(m.board2.pending_garbage[0].power == 5)

	m.board2.garbage_sent.emit(3)
	assert(m.board1.pending_garbage.size() == 1)
	assert(m.board1.pending_garbage[0].power == 3)

	# game_over on board1 means player 2 wins.
	m.board1.game_over.emit()
	assert(m.end_panel.visible == true)
	assert(m.end_label.text == "Joueur 2 gagne !")
	assert(m.board1.is_processing() == false)
	assert(m.board2.is_processing() == false)

	print("ALL TESTS PASSED")
	quit()
	return true
```

- [ ] **Step 2: Run test to verify it fails**

Run the test runner pattern with `<file>` = `test_match`.
Expected: `ERROR: Failed to load script` — `res://scenes/Match.tscn` does not exist.

- [ ] **Step 3: Create `scripts/match.gd`**

```gdscript
extends Node2D

@onready var board1: Node2D = $Board1
@onready var board2: Node2D = $Board2
@onready var score_label1: Label = $ScoreLabel1
@onready var score_label2: Label = $ScoreLabel2
@onready var garbage_label1: Label = $GarbageLabel1
@onready var garbage_label2: Label = $GarbageLabel2
@onready var waiting_panel: ColorRect = $WaitingPanel
@onready var waiting_label: Label = $WaitingPanel/WaitingLabel
@onready var end_panel: ColorRect = $EndPanel
@onready var end_label: Label = $EndPanel/EndLabel
@onready var restart_button: Button = $EndPanel/RestartButton

var _started := false

func _ready() -> void:
	board1.input_device = 0
	board2.input_device = 1
	board1.set_process(false)
	board2.set_process(false)

	board1.score_changed.connect(func(s: int): score_label1.text = "Score: %d" % s)
	board2.score_changed.connect(func(s: int): score_label2.text = "Score: %d" % s)

	board1.garbage_sent.connect(board2.receive_garbage)
	board2.garbage_sent.connect(board1.receive_garbage)

	board1.game_over.connect(func(): _on_game_over(2))
	board2.game_over.connect(func(): _on_game_over(1))

	restart_button.pressed.connect(func(): get_tree().reload_current_scene())
	end_panel.visible = false

func _process(_delta: float) -> void:
	if not _started:
		var connected := Input.get_connected_joypads().size()
		waiting_label.text = "En attente de manettes (%d/2 connectées)" % min(connected, 2)
		if connected >= 2:
			_started = true
			waiting_panel.visible = false
			board1.set_process(true)
			board2.set_process(true)
		return

	garbage_label1.text = "Garbage entrant: %d" % board1.pending_garbage.size()
	garbage_label2.text = "Garbage entrant: %d" % board2.pending_garbage.size()

func _on_game_over(winner: int) -> void:
	board1.set_process(false)
	board2.set_process(false)
	end_label.text = "Joueur %d gagne !" % winner
	end_panel.visible = true
```

- [ ] **Step 4: Create `scenes/Match.tscn`**

```
[gd_scene load_steps=3 format=3]

[ext_resource type="PackedScene" path="res://scenes/Board.tscn" id="1"]
[ext_resource type="Script" path="res://scripts/match.gd" id="2"]

[node name="Match" type="Node2D"]
script = ExtResource("2")

[node name="Board1" parent="." instance=ExtResource("1")]
position = Vector2(20, 20)

[node name="Board2" parent="." instance=ExtResource("1")]
position = Vector2(520, 20)

[node name="ScoreLabel1" type="Label" parent="."]
offset_left = 20.0
offset_top = 0.0
offset_right = 200.0
offset_bottom = 20.0
theme_override_font_sizes/font_size = 18
text = "Score: 0"

[node name="ScoreLabel2" type="Label" parent="."]
offset_left = 520.0
offset_top = 0.0
offset_right = 700.0
offset_bottom = 20.0
theme_override_font_sizes/font_size = 18
text = "Score: 0"

[node name="GarbageLabel1" type="Label" parent="."]
offset_left = 20.0
offset_top = 790.0
offset_right = 250.0
offset_bottom = 810.0
theme_override_font_sizes/font_size = 16
text = "Garbage entrant: 0"

[node name="GarbageLabel2" type="Label" parent="."]
offset_left = 520.0
offset_top = 790.0
offset_right = 750.0
offset_bottom = 810.0
theme_override_font_sizes/font_size = 16
text = "Garbage entrant: 0"

[node name="WaitingPanel" type="ColorRect" parent="."]
offset_right = 920.0
offset_bottom = 800.0
color = Color(0, 0, 0, 0.85)

[node name="WaitingLabel" type="Label" parent="WaitingPanel"]
offset_left = 200.0
offset_top = 380.0
offset_right = 720.0
offset_bottom = 420.0
theme_override_font_sizes/font_size = 28
horizontal_alignment = 1
text = "En attente de manettes (0/2 connectées)"

[node name="EndPanel" type="ColorRect" parent="."]
visible = false
offset_right = 920.0
offset_bottom = 800.0
color = Color(0, 0, 0, 0.7)

[node name="EndLabel" type="Label" parent="EndPanel"]
offset_left = 260.0
offset_top = 350.0
offset_right = 660.0
offset_bottom = 410.0
theme_override_font_sizes/font_size = 40
horizontal_alignment = 1
text = ""

[node name="RestartButton" type="Button" parent="EndPanel"]
offset_left = 410.0
offset_top = 450.0
offset_right = 510.0
offset_bottom = 500.0
text = "Rejouer"
```

- [ ] **Step 5: Run test to verify it passes**

Run the test runner pattern with `<file>` = `test_match`.
Expected: `ALL TESTS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add scripts/match.gd scenes/Match.tscn tests/test_match.gd
git commit -m "Add Match scene: 2-player boards, garbage routing, win/lose"
```

---

### Task 10: Wire Match as the main scene, resize window, manual playtest

**Files:**
- Modify: `project.godot`

- [ ] **Step 1: Update `project.godot`**

Change:

```
config/name="Swap & Clash"
run/main_scene="res://scenes/Game.tscn"
config/features=PackedStringArray("4.6")

[display]

window/size/viewport_width=620
window/size/viewport_height=800
```

to:

```
config/name="Swap & Clash"
run/main_scene="res://scenes/Match.tscn"
config/features=PackedStringArray("4.6")

[display]

window/size/viewport_width=920
window/size/viewport_height=800
```

- [ ] **Step 2: Verify the project still imports cleanly**

```bash
pkill -f "Godot.app/Contents/MacOS/Godot" 2>/dev/null; sleep 1; cd "/Users/floriojulien/Code/Swap & Clash" && (/Users/floriojulien/Downloads/Godot.app/Contents/MacOS/Godot --headless --import > /tmp/import.log 2>&1 &) ; sleep 8; pkill -f "Godot.app/Contents/MacOS/Godot"; sleep 1; cat /tmp/import.log
```

Expected: no `SCRIPT ERROR` / `Parse Error` lines.

- [ ] **Step 3: Commit**

```bash
git add project.godot
git commit -m "Set Match as the main scene and resize window for 2 players"
```

- [ ] **Step 4: Manual playtest (requires the Godot editor and 2 gamepads)**

This step cannot be automated headlessly — open the project in the Godot 4.6 editor
(`/Users/floriojulien/Downloads/Godot.app`), connect 2 gamepads, run `Match.tscn`, and check:

- The "En attente de manettes" screen disappears once both gamepads are detected
- Each player's cursor responds to D-pad/stick + A (swap) + B (fast rise) on their own
  gamepad only
- Making a combo of 4+ or a chain sends a grey garbage block to the opponent's board after
  the ~2s telegraph
- The garbage block falls onto the opponent's stack, and clearing a match next to it shatters
  its bottom row into colored panels
- Making your own combo/chain while garbage is incoming cancels it (check the
  "Garbage entrant" counter decreases) and any leftover bounces back to the sender
- When one player's stack reaches the top, "Joueur X gagne !" is shown and "Rejouer" restarts
  the match
- Adjust `TELEGRAPH_DURATION`, `RISE_SPEED_NORMAL`/`FAST`, and animation durations in
  `board.gd` if the pacing feels off

---

## Self-Review Notes

- **Spec coverage**: combo/chain power formula (Task 1), shape conversion (Task 2),
  GarbageBlock visuals/states (Task 3), grid integration incl. match-scan/rise/visuals
  guards (Task 4), multi-cell gravity (Task 5), shatter-on-match + signal (Task 6),
  queue/telegraph/counter (Task 7), gamepad input (Task 8), 2-player Match scene with
  routing and win/lose (Task 9), main-scene wiring + window resize + playtest (Task 10).
  The visual telegraph indicator is simplified to a text counter (`GarbageLabel`) rather
  than the rectangle bars described in the spec — acceptable given the "placeholders
  simples" philosophy; can be refined visually later without logic changes.
- **Type consistency**: `_garbage_power_for(combo_size, chain) -> int`,
  `_garbage_shape_for_power(power) -> Dictionary {height, width}`,
  `_spawn_garbage_block(origin, width, height) -> GarbageBlock`, `_send_garbage(power)`,
  `receive_garbage(power)`, `pending_garbage` items `{power, telegraph_time, columns}` —
  used consistently from Task 2 through Task 9.
- **No placeholders**: every step has complete code; Task 10's manual playtest is
  intentionally manual (cannot be automated headlessly) and is documented as such, not as a
  TODO.
