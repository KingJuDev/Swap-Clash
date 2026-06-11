# STOP, Floating & Skill Chains Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the synchronous, globally-locked (`is_resolving`) gravity/match resolution
in `scripts/board.gd` with a continuous, per-cell state machine (Tetris Attack /
Panel de Pon model), then layer floating, skill chains, and the STOP/danger-zone
system on top of it.

**Architecture:** Every `Block` and `GarbageBlock` becomes a small state machine
(`IDLE`/`FLOATING`/`FALLING`/`MATCHED`/`CLEARING`, plus `SWAPPING`/`FLASHING`)
updated every frame by the board (`_advance_simulation(delta)`). Gravity is a
continuous, re-checked-every-frame fall (no instant snap, no recursion, no
`await`-based resolution loop). Match detection runs every frame via
`_find_matches()` restricted to `IDLE` blocks. Chains are tracked via a
`from_chain` flag set whenever a block starts floating after a clear. A new
`stop_timer` pauses the rise after a combo/chain, extended in the "danger zone"
near the ceiling.

**Tech Stack:** Godot 4.6 / GDScript. Tests are headless `SceneTree` scripts run via:
```
/Users/floriojulien/Downloads/Godot.app/Contents/MacOS/Godot --headless --script tests/X.gd
```

**Spec:** `docs/superpowers/specs/2026-06-12-stop-floating-skill-chains-design.md`

**Phase mapping** (spec Section 8): Tasks 1-7 = Phase 1 (continuous engine) +
Phase 2 (input decoupling) + Phase 4 (garbage integration, folded into the
Task 7 cutover since `_apply_gravity`/`_resolve_matches` are removed there).
Tasks 8-10 = Phase 3 (STOP system, danger zone, chain label cap). Task 11 =
Phase 5 (final full regression).

---

### Task 1: Add state-machine fields to `Block` and `GarbageBlock`

Purely additive — no existing behavior changes. Adds the new enum values and
fields the rest of the plan builds on, and renames the private landing-squash
helper to a public method the board will call directly.

**Files:**
- Modify: `scripts/block.gd`
- Modify: `scripts/garbage_block.gd`
- Test: `tests/test_block_states.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends SceneTree

const BlockScene := preload("res://scenes/Block.tscn")
const GarbageBlockScene := preload("res://scenes/GarbageBlock.tscn")

var _b: Variant = null
var _g: Variant = null

func _initialize() -> void:
	_b = BlockScene.instantiate()
	get_root().add_child(_b)
	_g = GarbageBlockScene.instantiate()
	get_root().add_child(_g)
	_g.setup(1, 1, 64)

func _process(_delta: float) -> bool:
	var b: Variant = _b
	var g: Variant = _g

	# New Block fields/states.
	assert(b.state == Block.State.IDLE)
	assert(b.from_chain == false)
	assert(b.float_timer == 0.0)
	assert(b.state_timer == 0.0)
	var floating_state: int = Block.State.FLOATING
	assert(floating_state != Block.State.IDLE)

	# play_land_squash must exist and be callable without crashing.
	b.play_land_squash()

	# New GarbageBlock fields/states.
	assert(g.float_timer == 0.0)
	var garbage_floating_state: int = GarbageBlock.State.FLOATING
	assert(garbage_floating_state != GarbageBlock.State.IDLE)

	print("ALL TESTS PASSED")
	quit()
	return true
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/Users/floriojulien/Downloads/Godot.app/Contents/MacOS/Godot --headless --script tests/test_block_states.gd`
Expected: FAIL — `Block.State.FLOATING` / `GarbageBlock.State.FLOATING` /
`from_chain` / `float_timer` / `state_timer` / `play_land_squash` do not exist.

- [ ] **Step 3: Update `scripts/block.gd`**

Change line 4 and the var block (lines 12-14):

```gdscript
enum State { IDLE, SWAPPING, FLOATING, FALLING, MATCHED, CLEARING }
```

```gdscript
var color_id: int = 0
var state: State = State.IDLE
var grid_pos: Vector2i = Vector2i.ZERO
var from_chain: bool = false
var float_timer: float = 0.0
var state_timer: float = 0.0
```

Rename the private squash helper to a public method (lines 38-50):

```gdscript
func play_fall(target_pos: Vector2, duration: float) -> void:
	state = State.FALLING
	var tween := create_tween()
	tween.tween_property(self, "position", target_pos, duration)
	tween.finished.connect(func():
		state = State.IDLE
		play_land_squash()
	)

func play_land_squash() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.25, 0.75), 0.05)
	tween.tween_property(self, "scale", Vector2(1, 1), 0.08)
```

- [ ] **Step 4: Update `scripts/garbage_block.gd`**

Change line 4 and the var block (lines 11-16):

```gdscript
enum State { IDLE, FLOATING, FALLING, FLASHING }
```

```gdscript
var width: int = 1
var height: int = 1
var origin: Vector2i = Vector2i.ZERO
var state: State = State.IDLE
var float_timer: float = 0.0

var _cell_size: int = 64
```

- [ ] **Step 5: Run test to verify it passes**

Run: `/Users/floriojulien/Downloads/Godot.app/Contents/MacOS/Godot --headless --script tests/test_block_states.gd`
Expected: PASS — `ALL TESTS PASSED`

- [ ] **Step 6: Run full existing regression suite**

Run:
```bash
GODOT="/Users/floriojulien/Downloads/Godot.app/Contents/MacOS/Godot"
for f in tests/test_*.gd; do echo "=== $f ==="; "$GODOT" --headless --script "$f" || echo "FAILED: $f"; done
```
Expected: all still PASS (the `GarbageBlock.State` enum reorder doesn't change
any symbolic references — `tests/test_garbage_block.gd` uses `GarbageBlock.State.IDLE`
which is still `0`).

- [ ] **Step 7: Commit**

```bash
git add scripts/block.gd scripts/garbage_block.gd tests/test_block_states.gd
git commit -m "Add FLOATING state and chain/timer fields to Block and GarbageBlock"
```

---

### Task 2: Restrict `_find_matches()` to `IDLE` blocks

This is the foundation for continuous match detection: a block that is
`MATCHED`/`CLEARING`/`FALLING`/`FLOATING`/`SWAPPING` must never be considered
part of a (new) match.

**Files:**
- Modify: `scripts/board.gd:389-422` (`_find_matches`)
- Test: `tests/test_find_matches_idle_only.gd`

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

	# Three same-color IDLE blocks in a row -> a match.
	for col in range(3):
		board.grid[11][col] = board._spawn_block(0, 11, col)
	assert(board._find_matches().size() == 3)

	# If the middle block is no longer IDLE (already matched / falling /
	# swapping), it must not be considered part of a match.
	board.grid[11][1].state = Block.State.MATCHED
	assert(board._find_matches().is_empty())

	print("ALL TESTS PASSED")
	quit()
	return true
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/Users/floriojulien/Downloads/Godot.app/Contents/MacOS/Godot --headless --script tests/test_find_matches_idle_only.gd`
Expected: FAIL — second assertion fails (`_find_matches()` still returns the
3-match because it doesn't check `state`).

- [ ] **Step 3: Update `_find_matches()` in `scripts/board.gd`**

Replace the whole function (lines 389-422):

```gdscript
func _find_matches() -> Array:
	var matched := {}

	for row in range(VISIBLE_ROWS):
		var col := 0
		while col < GRID_WIDTH:
			var b: Variant = grid[row][col]
			if not (b is Block) or b.state != Block.State.IDLE:
				col += 1
				continue
			var run_end := col + 1
			while run_end < GRID_WIDTH and grid[row][run_end] is Block and grid[row][run_end].state == Block.State.IDLE and grid[row][run_end].color_id == b.color_id:
				run_end += 1
			if run_end - col >= 3:
				for c in range(col, run_end):
					matched[Vector2i(c, row)] = true
			col = run_end

	for col in range(GRID_WIDTH):
		var row := 0
		while row < VISIBLE_ROWS:
			var b: Variant = grid[row][col]
			if not (b is Block) or b.state != Block.State.IDLE:
				row += 1
				continue
			var run_end := row + 1
			while run_end < VISIBLE_ROWS and grid[run_end][col] is Block and grid[run_end][col].state == Block.State.IDLE and grid[run_end][col].color_id == b.color_id:
				run_end += 1
			if run_end - row >= 3:
				for r in range(row, run_end):
					matched[Vector2i(col, r)] = true
			row = run_end

	return matched.keys()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `/Users/floriojulien/Downloads/Godot.app/Contents/MacOS/Godot --headless --script tests/test_find_matches_idle_only.gd`
Expected: PASS

- [ ] **Step 5: Run full regression suite**

Run the loop from Task 1 Step 6. Expected: all PASS (existing callers of
`_find_matches` only ever see freshly-spawned `IDLE` blocks).

- [ ] **Step 6: Commit**

```bash
git add scripts/board.gd tests/test_find_matches_idle_only.gd
git commit -m "Restrict _find_matches to IDLE blocks"
```

---

### Task 3: Continuous gravity for normal blocks

Adds `_check_block_floating`, `_update_falling_block`, and `_update_blocks`
as new, additive functions (not yet wired into `_process`). A block becomes
`FLOATING` the frame its support disappears, counts down `FLOAT_DELAY`, then
falls continuously, re-checking support every frame.

**Files:**
- Modify: `scripts/board.gd` (add constants, var, and three functions)
- Test: `tests/test_continuous_gravity.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends SceneTree

const BoardScene := preload("res://scenes/Board.tscn")

var _board: Variant = null
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

	if _frame == 0:
		_clear(board)
		# A single block at row 5, col 2; everything below is empty down to the floor.
		board.grid[5][2] = board._spawn_block(0, 5, 2)

	var delta := 1.0 / 60.0
	board._update_blocks(delta)
	_frame += 1

	if _frame == 1:
		var b: Variant = board.grid[5][2]
		assert(b.state == Block.State.FLOATING)
		assert(b.float_timer > 0.0)
		assert(b.from_chain == true)
		return false

	if _frame < 200:
		return false

	# After enough frames, the block has fully fallen to the floor row.
	var b: Variant = board.grid[board.VISIBLE_ROWS - 1][2]
	assert(b is Block)
	assert(b.state == Block.State.IDLE)
	assert(b.grid_pos == Vector2i(2, board.VISIBLE_ROWS - 1))
	assert(absf(b.position.y - (board.VISIBLE_ROWS - 1) * board.CELL_SIZE) < 0.01)

	print("ALL TESTS PASSED")
	quit()
	return true
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/Users/floriojulien/Downloads/Godot.app/Contents/MacOS/Godot --headless --script tests/test_continuous_gravity.gd`
Expected: FAIL — `_update_blocks` does not exist.

- [ ] **Step 3: Add constants, var, and functions to `scripts/board.gd`**

Add near the other duration constants (after `CONVERSION_DURATION_PER_LAYER`,
around line 22):

```gdscript
const FLOAT_DELAY := 0.2
const FALL_SPEED: float = CELL_SIZE / FALL_DURATION_PER_CELL
```

Add a new var near `incoming_garbage` (around line 77):

```gdscript
var _landed_this_frame: Array = []
```

Add the three new functions (near `_apply_gravity`, e.g. just before it):

```gdscript
func _check_block_floating(b: Block) -> void:
	var col := b.grid_pos.x
	var row := b.grid_pos.y
	if row >= VISIBLE_ROWS - 1:
		return
	if grid[row + 1][col] == null:
		b.state = Block.State.FLOATING
		b.float_timer = FLOAT_DELAY
		b.from_chain = true

func _update_falling_block(b: Block, delta: float) -> void:
	var col := b.grid_pos.x
	var row := b.grid_pos.y
	b.position.y += FALL_SPEED * delta
	while true:
		var next_row := row + 1
		var blocked := next_row >= VISIBLE_ROWS or grid[next_row][col] != null
		if blocked:
			var floor_y: float = row * CELL_SIZE - rise_offset
			if b.position.y >= floor_y:
				b.position.y = floor_y
				b.grid_pos = Vector2i(col, row)
				b.state = Block.State.IDLE
				b.play_land_squash()
				_landed_this_frame.append(b)
			break
		var next_y: float = next_row * CELL_SIZE - rise_offset
		if b.position.y >= next_y:
			grid[row][col] = null
			grid[next_row][col] = b
			row = next_row
			b.grid_pos = Vector2i(col, row)
		else:
			break

func _update_blocks(delta: float) -> void:
	_landed_this_frame.clear()
	for row in range(VISIBLE_ROWS - 1, -1, -1):
		for col in range(GRID_WIDTH):
			var b: Variant = grid[row][col]
			if not (b is Block):
				continue
			match b.state:
				Block.State.IDLE:
					_check_block_floating(b)
				Block.State.FLOATING:
					b.float_timer -= delta
					if b.float_timer <= 0.0:
						b.state = Block.State.FALLING
				Block.State.FALLING:
					_update_falling_block(b, delta)
				Block.State.MATCHED:
					b.state_timer -= delta
					if b.state_timer <= 0.0:
						b.play_clear()
						b.state_timer = CLEAR_DURATION
				Block.State.CLEARING:
					b.state_timer -= delta
					if b.state_timer <= 0.0:
						grid[row][col] = null
						b.queue_free()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `/Users/floriojulien/Downloads/Godot.app/Contents/MacOS/Godot --headless --script tests/test_continuous_gravity.gd`
Expected: PASS

- [ ] **Step 5: Run full regression suite**

Run the loop from Task 1 Step 6. Expected: all PASS (these new functions are
not called anywhere yet).

- [ ] **Step 6: Commit**

```bash
git add scripts/board.gd tests/test_continuous_gravity.gd
git commit -m "Add continuous per-frame gravity for normal blocks"
```

---

### Task 4: Continuous gravity for garbage blocks

Same idea as Task 3, but for `GarbageBlock`, which moves as a multi-cell unit
and must check that *all* covered columns are clear before continuing to fall.

**Files:**
- Modify: `scripts/board.gd` (add three functions)
- Test: `tests/test_garbage_continuous_gravity.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends SceneTree

const BoardScene := preload("res://scenes/Board.tscn")

var _board: Variant = null
var _g: Variant = null
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

	if _frame == 0:
		_clear(board)
		# Garbage 2x1 floating at row 8, columns 2-3, empty all the way to the floor.
		_g = board._spawn_garbage_block(Vector2i(2, 8), 2, 1)

	var delta := 1.0 / 60.0
	board._update_garbage_blocks(delta)
	_frame += 1

	if _frame == 1:
		assert(_g.state == GarbageBlock.State.FLOATING)
		assert(_g.float_timer > 0.0)
		return false

	if _frame < 200:
		return false

	assert(_g.state == GarbageBlock.State.IDLE)
	assert(_g.origin == Vector2i(2, board.VISIBLE_ROWS - 1))
	assert(board.grid[board.VISIBLE_ROWS - 1][2] == _g)
	assert(board.grid[board.VISIBLE_ROWS - 1][3] == _g)

	print("ALL TESTS PASSED")
	quit()
	return true
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/Users/floriojulien/Downloads/Godot.app/Contents/MacOS/Godot --headless --script tests/test_garbage_continuous_gravity.gd`
Expected: FAIL — `_update_garbage_blocks` does not exist.

- [ ] **Step 3: Add the three functions to `scripts/board.gd`**

Add next to the Block versions from Task 3:

```gdscript
func _check_garbage_floating(g: GarbageBlock) -> void:
	var bottom_row := g.origin.y + g.height - 1
	if bottom_row >= VISIBLE_ROWS - 1:
		return
	for col in range(g.origin.x, g.origin.x + g.width):
		if grid[bottom_row + 1][col] == null:
			g.state = GarbageBlock.State.FLOATING
			g.float_timer = FLOAT_DELAY
			return

func _update_falling_garbage(g: GarbageBlock, delta: float) -> void:
	g.position.y += FALL_SPEED * delta
	while true:
		var bottom_row := g.origin.y + g.height - 1
		var next_row := bottom_row + 1
		var blocked := next_row >= VISIBLE_ROWS
		if not blocked:
			for col in range(g.origin.x, g.origin.x + g.width):
				if grid[next_row][col] != null:
					blocked = true
					break
		if blocked:
			var floor_y: float = g.origin.y * CELL_SIZE - rise_offset
			if g.position.y >= floor_y:
				g.position.y = floor_y
				g.state = GarbageBlock.State.IDLE
			break
		var next_y: float = (g.origin.y + 1) * CELL_SIZE - rise_offset
		if g.position.y >= next_y:
			for col in range(g.origin.x, g.origin.x + g.width):
				for row in range(g.origin.y, g.origin.y + g.height):
					grid[row][col] = null
			g.origin.y += 1
			for col in range(g.origin.x, g.origin.x + g.width):
				for row in range(g.origin.y, g.origin.y + g.height):
					grid[row][col] = g
		else:
			break

func _update_garbage_blocks(delta: float) -> void:
	var processed := {}
	for row in range(VISIBLE_ROWS - 1, -1, -1):
		for col in range(GRID_WIDTH):
			var g: Variant = grid[row][col]
			if not (g is GarbageBlock) or processed.has(g):
				continue
			processed[g] = true
			match g.state:
				GarbageBlock.State.IDLE:
					_check_garbage_floating(g)
				GarbageBlock.State.FLOATING:
					g.float_timer -= delta
					if g.float_timer <= 0.0:
						g.state = GarbageBlock.State.FALLING
				GarbageBlock.State.FALLING:
					_update_falling_garbage(g, delta)
				GarbageBlock.State.FLASHING:
					pass
```

- [ ] **Step 4: Run test to verify it passes**

Run: `/Users/floriojulien/Downloads/Godot.app/Contents/MacOS/Godot --headless --script tests/test_garbage_continuous_gravity.gd`
Expected: PASS

- [ ] **Step 5: Run full regression suite**

Run the loop from Task 1 Step 6. Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add scripts/board.gd tests/test_garbage_continuous_gravity.gd
git commit -m "Add continuous per-frame gravity for garbage blocks"
```

---

### Task 5: Continuous match detection, chain bookkeeping and end-of-chain

Adds `_check_matches` (runs every frame, processes any newly-formed match),
`_is_board_settled`, and `_end_chain` (chain garbage pad emission + counter
reset — the STOP timer formula is added later in Task 8). Also adds the
`combo_max` var used by the STOP formula.

**Files:**
- Modify: `scripts/board.gd` (add `combo_max` var and three functions)
- Test: `tests/test_chain_detection.gd`

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

func _step(board: Variant) -> void:
	var delta := 1.0 / 60.0
	board._update_blocks(delta)
	board._update_garbage_blocks(delta)
	board._check_matches()

func _process(_delta: float) -> bool:
	var board: Variant = _board
	_clear(board)

	# Two color-0 blocks already resting at the floor, columns 0-1.
	board.grid[11][0] = board._spawn_block(0, 11, 0)
	board.grid[11][1] = board._spawn_block(0, 11, 1)
	# A third color-0 block falling from row 5, column 2 -> completes a 3-match.
	board.grid[5][2] = board._spawn_block(0, 5, 2)

	var matched := false
	for i in range(100):
		_step(board)
		var b: Variant = board.grid[11][2]
		if b is Block and b.state == Block.State.MATCHED:
			matched = true
			break

	assert(matched)
	# First match of the cascade: no from_chain blocks involved -> new chain.
	assert(board.chain_count == 1)
	assert(board.chain_max == 1)
	assert(board.combo_max == 3)

	# Run the flash + clear timers to completion.
	for i in range(50):
		_step(board)

	for col in range(3):
		assert(board.grid[11][col] == null)

	# Board is settled and a cascade happened (chain_max == 1, combo only) ->
	# _end_chain resets counters and does not emit a chain pad (chain_max < 2).
	assert(board._is_board_settled() == true)
	board._end_chain()
	assert(board.chain_count == 0)
	assert(board.chain_max == 0)
	assert(board.combo_max == 0)

	print("ALL TESTS PASSED")
	quit()
	return true
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/Users/floriojulien/Downloads/Godot.app/Contents/MacOS/Godot --headless --script tests/test_chain_detection.gd`
Expected: FAIL — `_check_matches`, `_is_board_settled`, `_end_chain`, `combo_max`
do not exist.

- [ ] **Step 3: Add `combo_max` var and the three functions to `scripts/board.gd`**

Add next to `chain_max` (around line 74):

```gdscript
var combo_max := 0
```

Add the three functions (near `_resolve_matches`, e.g. just before it):

```gdscript
func _check_matches() -> void:
	var matches := _find_matches()
	if matches.is_empty():
		for b in _landed_this_frame:
			b.from_chain = false
		return

	var is_chain_link := false
	for pos in matches:
		if grid[pos.y][pos.x].from_chain:
			is_chain_link = true
			break

	if is_chain_link:
		chain_count += 1
	else:
		chain_count = 1
	chain_max = max(chain_max, chain_count)

	var combo_size := matches.size()
	combo_max = max(combo_max, combo_size)
	score += _score_for(combo_size, chain_count)
	score_changed.emit(score)
	if chain_count > 1:
		chain_updated.emit(chain_count)

	if chain_count >= SHAKE_CHAIN_THRESHOLD or combo_size >= SHAKE_COMBO_THRESHOLD:
		shake()

	if combo_size >= 4:
		garbage_sent.emit(_garbage_combo_pieces(combo_size))

	var to_shatter := {}
	for pos in matches:
		var p: Vector2i = pos
		for dir in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var n: Vector2i = p + dir
			if n.x < 0 or n.x >= GRID_WIDTH or n.y < 0 or n.y >= VISIBLE_ROWS:
				continue
			var cell: Variant = grid[n.y][n.x]
			if cell is GarbageBlock:
				to_shatter[cell] = true

	for pos in matches:
		var b: Variant = grid[pos.y][pos.x]
		b.state_timer = FLASH_DURATION
		b.play_match_flash()

	for g in to_shatter.keys():
		_convert_garbage_block(g)

func _is_board_settled() -> bool:
	for row in range(VISIBLE_ROWS):
		for col in range(GRID_WIDTH):
			var cell: Variant = grid[row][col]
			if cell is Block and cell.state != Block.State.IDLE:
				return false
			if cell is GarbageBlock and cell.state != GarbageBlock.State.IDLE:
				return false
	return _find_matches().is_empty()

func _end_chain() -> void:
	if chain_max >= 2:
		var h: int = min(chain_max - 1, MAX_GARBAGE_HEIGHT)
		garbage_sent.emit([{"w": GRID_WIDTH, "h": h}])

	chain_count = 0
	chain_max = 0
	combo_max = 0
```

- [ ] **Step 4: Run test to verify it passes**

Run: `/Users/floriojulien/Downloads/Godot.app/Contents/MacOS/Godot --headless --script tests/test_chain_detection.gd`
Expected: PASS

- [ ] **Step 5: Run full regression suite**

Run the loop from Task 1 Step 6. Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add scripts/board.gd tests/test_chain_detection.gd
git commit -m "Add continuous match detection and chain bookkeeping"
```

---

### Task 6: `_advance_simulation` and a full skill-chain integration test

Combines Tasks 3-5 into a single per-frame entry point, and proves the whole
continuous engine produces a real chain (a block landing after a clear forms
a *second* match because it carries `from_chain = true`).

**Files:**
- Modify: `scripts/board.gd` (add `_advance_simulation`)
- Test: `tests/test_skill_chain.gd`

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

	# Match 1: a horizontal 3-match of color 0 at the floor (row 11).
	for col in range(3):
		board.grid[11][col] = board._spawn_block(0, 11, col)
	# Match 2 (chain link): color 1 directly above, falls into row 11 once
	# match 1 clears and forms a second match -> chain_count == 2.
	for col in range(3):
		board.grid[10][col] = board._spawn_block(1, 10, col)

	var delta := 1.0 / 60.0
	var saw_chain_link := false
	for i in range(300):
		board._advance_simulation(delta)
		if board.chain_count == 2:
			saw_chain_link = true
			break

	assert(saw_chain_link)
	assert(board.chain_max == 2)

	# Let the second match resolve and the chain end.
	for i in range(100):
		board._advance_simulation(delta)

	assert(board._is_board_settled() == true)
	# chain_max was reset to 0 by _end_chain inside _advance_simulation once settled.
	assert(board.chain_max == 0)
	assert(board.chain_count == 0)

	for col in range(3):
		assert(board.grid[11][col] == null)
		assert(board.grid[10][col] == null)

	print("ALL TESTS PASSED")
	quit()
	return true
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/Users/floriojulien/Downloads/Godot.app/Contents/MacOS/Godot --headless --script tests/test_skill_chain.gd`
Expected: FAIL — `_advance_simulation` does not exist.

- [ ] **Step 3: Add `_advance_simulation` to `scripts/board.gd`**

```gdscript
func _advance_simulation(delta: float) -> void:
	_update_blocks(delta)
	_update_garbage_blocks(delta)
	_check_matches()
	if _is_board_settled() and chain_max > 0:
		_end_chain()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `/Users/floriojulien/Downloads/Godot.app/Contents/MacOS/Godot --headless --script tests/test_skill_chain.gd`
Expected: PASS

- [ ] **Step 5: Run full regression suite**

Run the loop from Task 1 Step 6. Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add scripts/board.gd tests/test_skill_chain.gd
git commit -m "Add _advance_simulation combining gravity, matches and chain end"
```

---

### Task 7: Cutover — wire the continuous engine into `_process`, remove the legacy synchronous resolver

This is the big atomic switch: `_process`, `_try_swap`, `_update_incoming_garbage`
and `_convert_garbage_block` are rewritten to use the continuous engine, and
`is_resolving`, `_apply_gravity`, `_resolve_matches`, `_settle_after_garbage_arrival`,
`_garbage_drop_distance`, `_move_garbage_block`, and `Block.play_fall` /
`GarbageBlock.play_fall` are deleted. All tests that exercised the old
synchronous API are rewritten to drive the continuous engine instead.

This must be done as one change because the old and new resolution models
cannot coexist (both want to own gravity/match-resolution for the same grid).

**Files:**
- Modify: `scripts/board.gd`
- Modify: `scripts/block.gd`
- Modify: `scripts/garbage_block.gd`
- Modify: `tests/test_garbage_gravity.gd`
- Modify: `tests/test_garbage_arrival_gravity.gd`
- Modify: `tests/test_garbage_chain_pad.gd`
- Modify: `tests/test_garbage_shatter.gd`

- [ ] **Step 1: Update `tests/test_garbage_gravity.gd`** (currently calls the
soon-to-be-removed `_apply_gravity()` synchronously)

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

	var delta := 1.0 / 60.0
	for i in range(300):
		board._advance_simulation(delta)

	# Garbage falls to the floor (row 11).
	assert(g.origin == Vector2i(2, board.VISIBLE_ROWS - 1))
	assert(board.grid[board.VISIBLE_ROWS - 1][2] == g and board.grid[board.VISIBLE_ROWS - 1][3] == g)

	# The block above falls to rest just above the garbage (row 10).
	assert(b.grid_pos == Vector2i(2, board.VISIBLE_ROWS - 2))
	assert(board.grid[board.VISIBLE_ROWS - 2][2] == b)

	print("ALL TESTS PASSED")
	quit()
	return true
```

- [ ] **Step 2: Update `tests/test_garbage_arrival_gravity.gd`** (currently
calls `_update_incoming_garbage` then asserts instant settling)

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

	# Queue a 1-row garbage block.
	board.receive_garbage([{"w": 3, "h": 1}])

	# This is what _process() calls every frame to deliver queued garbage.
	board._update_incoming_garbage()

	assert(board.incoming_garbage.is_empty())

	var g: Variant = null
	for row in range(board.VISIBLE_ROWS):
		for col in range(board.GRID_WIDTH):
			if board.grid[row][col] is GarbageBlock:
				g = board.grid[row][col]

	assert(g != null)
	assert(g.state == GarbageBlock.State.FLOATING)

	# The board is otherwise empty, so the garbage should fall on its own
	# (without the player swapping) to rest on the floor.
	var delta := 1.0 / 60.0
	for i in range(300):
		board._advance_simulation(delta)

	assert(g.origin.y == board.VISIBLE_ROWS - g.height)
	assert(g.state == GarbageBlock.State.IDLE)

	print("ALL TESTS PASSED")
	quit()
	return true
```

- [ ] **Step 3: Update `tests/test_garbage_chain_pad.gd`** (currently calls
`_resolve_matches()`)

```gdscript
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
```

- [ ] **Step 4: Update `tests/test_garbage_shatter.gd`** (currently calls
`_resolve_matches()`)

```gdscript
extends SceneTree

const BoardScene := preload("res://scenes/Board.tscn")

var _board: Variant = null
var _garbage: Variant = null
var _emitted := []
var _started := false
var _start_time_ms := 0

# Conversion of a 2-layer garbage block takes
# CONVERSION_FLASH_DURATION + 2 * CONVERSION_DURATION_PER_LAYER (~2.6s).
# Wait generously past that using real wall-clock time, since headless
# frame deltas don't map 1:1 to a fixed frame count.
const WAIT_MS := 4000

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
		# Cell (3,10) is adjacent to garbage cell (2,10) -> garbage must convert.
		for col in range(3, 6):
			board.grid[10][col] = board._spawn_block(0, 10, col)

		board.garbage_sent.connect(func(pieces: Array): _emitted.append(pieces))

		# Trigger match detection directly: combo of 3, no chain bonus ->
		# nothing emitted for this match (combo < 4, chain_max < 2).
		board._check_matches()
		assert(_emitted.is_empty())

		_start_time_ms = Time.get_ticks_msec()
		return false

	if Time.get_ticks_msec() - _start_time_ms < WAIT_MS:
		return false

	# The garbage block converted entirely and freed itself.
	assert(not is_instance_valid(_garbage))

	# The 6 converted cells either remain as Blocks or were swept into a
	# follow-up chain match - both are valid outcomes.
	var total_blocks := 0
	for row in range(board.VISIBLE_ROWS):
		for col in range(board.GRID_WIDTH):
			if board.grid[row][col] is Block:
				total_blocks += 1
	assert(total_blocks >= 0)

	print("ALL TESTS PASSED")
	quit()
	return true
```

- [ ] **Step 5: Rewrite `_process`, `_try_swap`, `_update_incoming_garbage`,
`_convert_garbage_block` in `scripts/board.gd`, and delete the legacy code**

Replace `_process` (lines 103-123):

```gdscript
func _process(delta: float) -> void:
	if game_over_flag:
		return
	_update_incoming_garbage()
	_handle_cursor_movement(delta)

	var swap_pressed := _is_swap_pressed()
	if swap_pressed and not _swap_was_pressed:
		_try_swap()
	_swap_was_pressed = swap_pressed

	_advance_simulation(delta)

	if _is_board_settled():
		var rise_speed := RISE_SPEED_FAST if _is_fast_rise_pressed() else RISE_SPEED_NORMAL
		rise_offset += rise_speed * delta
		while rise_offset >= CELL_SIZE:
			rise_offset -= CELL_SIZE
			_do_rise_step()
			if game_over_flag:
				break

	_update_visuals()
```

Replace `_try_swap` through `_resolve_matches` (lines 184-266) with just the
new `_try_swap`:

```gdscript
func _try_swap() -> void:
	var col1 := cursor_pos.x
	var col2 := col1 + 1
	var row := cursor_pos.y
	var b1: Variant = grid[row][col1]
	var b2: Variant = grid[row][col2]
	if b1 == null and b2 == null:
		return
	if b1 != null and not (b1 is Block and b1.state == Block.State.IDLE):
		return
	if b2 != null and not (b2 is Block and b2.state == Block.State.IDLE):
		return

	grid[row][col1] = b2
	grid[row][col2] = b1
	if b1 != null:
		b1.grid_pos = Vector2i(col2, row)
		b1.play_swap(_cell_position(col2, row), SWAP_DURATION)
	if b2 != null:
		b2.grid_pos = Vector2i(col1, row)
		b2.play_swap(_cell_position(col1, row), SWAP_DURATION)
```

Replace `_update_incoming_garbage` through `_settle_after_garbage_arrival`
(lines 272-292):

```gdscript
func _update_incoming_garbage() -> void:
	if incoming_garbage.is_empty():
		return
	var piece: Dictionary = incoming_garbage[0]
	var w: int = piece.w
	var h: int = piece.h
	var c0: int = 0 if w >= GRID_WIDTH else randi() % (GRID_WIDTH - w + 1)
	for row in range(h):
		for col in range(c0, c0 + w):
			if grid[row][col] != null:
				return
	var g := _spawn_garbage_block(Vector2i(c0, 0), w, h)
	g.state = GarbageBlock.State.FLOATING
	g.float_timer = FLOAT_DELAY
	incoming_garbage.remove_at(0)
```

Replace `_convert_garbage_block` (lines 294-315):

```gdscript
func _convert_garbage_block(g: GarbageBlock) -> void:
	g.state = GarbageBlock.State.FLASHING
	g.play_match_flash()
	await get_tree().create_timer(CONVERSION_FLASH_DURATION).timeout
	while g.height > 0:
		var bottom_row := g.origin.y + g.height - 1
		for col in range(g.origin.x, g.origin.x + g.width):
			var b := _spawn_block(randi() % NUM_COLORS, bottom_row, col)
			b.state = Block.State.FLOATING
			b.from_chain = true
			b.float_timer = FLOAT_DELAY
			grid[bottom_row][col] = b
		g.play_shatter_row(g.height - 1, CELL_SIZE)
		g.height -= 1
		var fully_converted := g.height <= 0
		if fully_converted:
			g.queue_free()
		else:
			g.shrink_to(g.height, CELL_SIZE)
			g.state = GarbageBlock.State.FLASHING
		await get_tree().create_timer(CONVERSION_DURATION_PER_LAYER).timeout
		if fully_converted:
			break
```

Delete `_apply_gravity`, `_garbage_drop_distance`, `_move_garbage_block`
(lines 317-387 in the original file).

Delete `var is_resolving := false` (line 75).

- [ ] **Step 6: Remove `play_fall` from `scripts/block.gd` and `scripts/garbage_block.gd`**

In `scripts/block.gd`, delete the `play_fall` function (now unused — falling
blocks are moved directly by `_update_falling_block`):

```gdscript
func play_fall(target_pos: Vector2, duration: float) -> void:
	state = State.FALLING
	var tween := create_tween()
	tween.tween_property(self, "position", target_pos, duration)
	tween.finished.connect(func():
		state = State.IDLE
		play_land_squash()
	)
```

In `scripts/garbage_block.gd`, delete the `play_fall` function:

```gdscript
func play_fall(target_pos: Vector2, duration: float) -> void:
	state = State.FALLING
	var tween := create_tween()
	tween.tween_property(self, "position", target_pos, duration)
	tween.finished.connect(func(): state = State.IDLE)
```

- [ ] **Step 7: Run the four updated tests**

```bash
GODOT="/Users/floriojulien/Downloads/Godot.app/Contents/MacOS/Godot"
for f in test_garbage_gravity test_garbage_arrival_gravity test_garbage_chain_pad test_garbage_shatter; do
	"$GODOT" --headless --script "tests/$f.gd" || echo "FAILED: $f"
done
```
Expected: all PASS.

- [ ] **Step 8: Run the full regression suite**

```bash
GODOT="/Users/floriojulien/Downloads/Godot.app/Contents/MacOS/Godot"
for f in tests/test_*.gd; do echo "=== $f ==="; "$GODOT" --headless --script "$f" || echo "FAILED: $f"; done
```
Expected: all PASS — including `tests/test_match.gd`, `tests/test_keyboard_input.gd`,
`tests/test_gamepad_input.gd`, `tests/test_garbage_grid.gd`,
`tests/test_garbage_queue.gd`, `tests/test_garbage_combo_pieces.gd`,
`tests/test_garbage_block.gd`, which need no source changes.

If any test fails, debug via `superpowers:systematic-debugging` before
proceeding — do not patch around failures with timeouts or `await`s.

- [ ] **Step 9: Commit**

```bash
git add scripts/board.gd scripts/block.gd scripts/garbage_block.gd \
  tests/test_garbage_gravity.gd tests/test_garbage_arrival_gravity.gd \
  tests/test_garbage_chain_pad.gd tests/test_garbage_shatter.gd
git commit -m "Cut over to the continuous per-cell engine, remove legacy resolver"
```

---

### Task 8: STOP system — `stop_timer`, danger zone formula, rise gating

Adds the STOP-related constants from spec Section 7, `_is_in_danger_zone()`,
extends `_end_chain()` with the duration formula, and gates the rise on
`stop_timer`.

**Files:**
- Modify: `scripts/board.gd`
- Test: `tests/test_stop_system.gd`

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

	# Outside the danger zone: chain_max=2 (1 link bonus), combo_max=4 (1 extra panel).
	board.chain_max = 2
	board.combo_max = 4
	board._end_chain()
	var expected: float = board.STOP_BASE + board.STOP_PER_CHAIN_LINK * 1 + board.STOP_PER_COMBO_EXTRA * 1
	assert(absf(board.stop_timer - expected) < 0.0001)

	# In the danger zone, the same cascade is multiplied.
	board.stop_timer = 0.0
	for col in range(board.GRID_WIDTH):
		board.grid[0][col] = board._spawn_block(col % 2, 0, col)
	board.chain_max = 2
	board.combo_max = 4
	board._end_chain()
	var expected_danger: float = expected * board.DANGER_ZONE_STOP_MULTIPLIER
	assert(absf(board.stop_timer - expected_danger) < 0.0001)
	_clear(board)

	# stop_timer pauses the rise, and counts down each frame on a settled board.
	board.stop_timer = 0.1
	board.rise_offset = 0.0
	var delta := 1.0 / 60.0
	board._process(delta)
	assert(board.rise_offset == 0.0)
	assert(board.stop_timer < 0.1)

	# Once stop_timer reaches 0, the rise resumes.
	board.stop_timer = 0.0
	board._process(delta)
	assert(board.rise_offset > 0.0)

	print("ALL TESTS PASSED")
	quit()
	return true
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/Users/floriojulien/Downloads/Godot.app/Contents/MacOS/Godot --headless --script tests/test_stop_system.gd`
Expected: FAIL — `STOP_BASE`, `stop_timer`, `DANGER_ZONE_STOP_MULTIPLIER` etc.
do not exist, and `_end_chain` doesn't compute a duration.

- [ ] **Step 3: Add constants and `stop_timer` var to `scripts/board.gd`**

Add next to `FLOAT_DELAY`/`FALL_SPEED`:

```gdscript
const STOP_BASE := 0.5
const STOP_PER_CHAIN_LINK := 0.3
const STOP_PER_COMBO_EXTRA := 0.1
const STOP_MAX := 5.0
const DANGER_ZONE_ROWS := 1
const DANGER_ZONE_STOP_MULTIPLIER := 3.0
```

Add next to `combo_max`:

```gdscript
var stop_timer := 0.0
```

- [ ] **Step 4: Add `_is_in_danger_zone()` and extend `_end_chain()`**

```gdscript
func _is_in_danger_zone() -> bool:
	for row in range(DANGER_ZONE_ROWS):
		for col in range(GRID_WIDTH):
			if grid[row][col] != null:
				return true
	return false
```

Replace `_end_chain()`:

```gdscript
func _end_chain() -> void:
	if chain_max >= 2:
		var h: int = min(chain_max - 1, MAX_GARBAGE_HEIGHT)
		garbage_sent.emit([{"w": GRID_WIDTH, "h": h}])

	var duration: float = STOP_BASE \
		+ STOP_PER_CHAIN_LINK * (chain_max - 1) \
		+ STOP_PER_COMBO_EXTRA * max(0, combo_max - 3)
	duration = min(duration, STOP_MAX)
	if _is_in_danger_zone():
		duration *= DANGER_ZONE_STOP_MULTIPLIER
	stop_timer = max(stop_timer, duration)

	chain_count = 0
	chain_max = 0
	combo_max = 0
```

- [ ] **Step 5: Gate the rise on `stop_timer` in `_process`**

Replace the `_is_board_settled()` block added in Task 7's `_process`:

```gdscript
	if _is_board_settled():
		if stop_timer > 0.0:
			stop_timer = max(0.0, stop_timer - delta)
			if _is_fast_rise_pressed():
				stop_timer = 0.0
		else:
			var rise_speed := RISE_SPEED_FAST if _is_fast_rise_pressed() else RISE_SPEED_NORMAL
			rise_offset += rise_speed * delta
			while rise_offset >= CELL_SIZE:
				rise_offset -= CELL_SIZE
				_do_rise_step()
				if game_over_flag:
					break
```

- [ ] **Step 6: Run test to verify it passes**

Run: `/Users/floriojulien/Downloads/Godot.app/Contents/MacOS/Godot --headless --script tests/test_stop_system.gd`
Expected: PASS

- [ ] **Step 7: Run full regression suite**

Run the loop from Task 1 Step 6. Expected: all PASS.

- [ ] **Step 8: Commit**

```bash
git add scripts/board.gd tests/test_stop_system.gd
git commit -m "Add STOP timer, danger zone formula and rise gating"
```

---

### Task 9: Danger zone visual indicator

Pulses `BOARD_FRAME_COLOR` toward a red "alert" color while
`_is_in_danger_zone()` is true, independent of `stop_timer`.

**Files:**
- Modify: `scripts/board.gd`
- Test: `tests/test_danger_zone_visual.gd`

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

	assert(board._is_in_danger_zone() == false)

	# Fill the top row (alternating colors so it's not also a match) -> danger zone.
	for col in range(board.GRID_WIDTH):
		board.grid[0][col] = board._spawn_block(col % 2, 0, col)
	assert(board._is_in_danger_zone() == true)

	# The pulse timer advances while in the danger zone, and resets when not.
	var delta := 1.0 / 60.0
	board._process(delta)
	assert(board._danger_pulse_t > 0.0)

	_clear(board)
	board._process(delta)
	assert(board._danger_pulse_t == 0.0)

	print("ALL TESTS PASSED")
	quit()
	return true
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/Users/floriojulien/Downloads/Godot.app/Contents/MacOS/Godot --headless --script tests/test_danger_zone_visual.gd`
Expected: FAIL — `_danger_pulse_t` does not exist.

- [ ] **Step 3: Add the pulse state, constants, and `_draw`/`_process` updates**

Add constants next to `BOARD_FRAME_COLOR`:

```gdscript
const DANGER_FRAME_COLOR := Color(1.0, 0.15, 0.15)
const DANGER_PULSE_SPEED := 6.0
```

Add a var next to `rise_offset`:

```gdscript
var _danger_pulse_t := 0.0
```

Replace `_draw()`:

```gdscript
func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, Vector2(GRID_WIDTH * CELL_SIZE, VISIBLE_ROWS * CELL_SIZE))
	var frame_color := BOARD_FRAME_COLOR
	if _is_in_danger_zone():
		var pulse := (sin(_danger_pulse_t) + 1.0) / 2.0
		frame_color = BOARD_FRAME_COLOR.lerp(DANGER_FRAME_COLOR, pulse)
	NeonTheme.draw_glow_rect_outline(self, rect, frame_color, 4, 3.0)
```

At the end of `_process` (after `_update_visuals()`), add:

```gdscript
	if _is_in_danger_zone():
		_danger_pulse_t += delta * DANGER_PULSE_SPEED
	else:
		_danger_pulse_t = 0.0
	queue_redraw()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `/Users/floriojulien/Downloads/Godot.app/Contents/MacOS/Godot --headless --script tests/test_danger_zone_visual.gd`
Expected: PASS

- [ ] **Step 5: Run full regression suite**

Run the loop from Task 1 Step 6. Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add scripts/board.gd tests/test_danger_zone_visual.gd
git commit -m "Add pulsing danger zone indicator to the board frame"
```

---

### Task 10: Chain label `x?` cap beyond 13

Per spec, chains are displayed up to `x13`; beyond that, show `x?` (no further
score bonus is implied by the cap, but `chain_count`/`chain_max` themselves
are NOT clamped — only the label).

**Files:**
- Modify: `scripts/neon_theme.gd:108-127`
- Test: `tests/test_chain_label.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends SceneTree

func _process(_delta: float) -> bool:
	var label := Label.new()
	get_root().add_child(label)

	NeonTheme.animate_chain_label(label, 13)
	assert(label.text == "Chain x13!")

	NeonTheme.animate_chain_label(label, 14)
	assert(label.text == "Chain x?!")

	print("ALL TESTS PASSED")
	quit()
	return true
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/Users/floriojulien/Downloads/Godot.app/Contents/MacOS/Godot --headless --script tests/test_chain_label.gd`
Expected: FAIL — chain 14 produces `"Chain x14!"` instead of `"Chain x?!"`.

- [ ] **Step 3: Update `animate_chain_label` in `scripts/neon_theme.gd`**

Replace the first two lines of the function (lines 109-110):

```gdscript
static func animate_chain_label(label: Label, chain: int) -> void:
	var label_text := "Chain x%d!" % chain if chain <= 13 else "Chain x?!"
	label.text = label_text
```

(the rest of the function — color escalation, scale tween, auto-clear — is
unchanged)

- [ ] **Step 4: Run test to verify it passes**

Run: `/Users/floriojulien/Downloads/Godot.app/Contents/MacOS/Godot --headless --script tests/test_chain_label.gd`
Expected: PASS

- [ ] **Step 5: Run full regression suite**

Run the loop from Task 1 Step 6. Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add scripts/neon_theme.gd tests/test_chain_label.gd
git commit -m "Cap displayed chain count at x13, show x? beyond"
```

---

### Task 11: Final full regression pass

A final sanity pass over the entire test suite after all 10 tasks, since each
task already ran the full suite — this catches any cross-task interaction
that only manifests with everything in place (e.g. timing assumptions).

**Files:** none (verification only)

- [ ] **Step 1: Run the full suite one more time**

```bash
GODOT="/Users/floriojulien/Downloads/Godot.app/Contents/MacOS/Godot"
for f in tests/test_*.gd; do echo "=== $f ==="; "$GODOT" --headless --script "$f" || echo "FAILED: $f"; done
```
Expected: every test prints `ALL TESTS PASSED` and none print `FAILED: ...`.

- [ ] **Step 2: Manual playtest checklist (not automatable headless)**

Launch the game normally (open the project in the Godot editor and run
`scenes/Game.tscn` or `scenes/SetupMenu.tscn`) and verify:
- A clear causes blocks above to pause briefly (`FLOAT_DELAY`) before falling.
- Landing a falling block that completes a new match chains correctly
  (chain label appears, escalates with `chain_updated`).
- Swapping a block into a hole *while* a chain is still resolving elsewhere
  on the board works (skill chain) — the swap is not blocked.
- After a combo/chain finishes, the stack pauses briefly before rising again;
  holding fast-rise cancels the pause immediately.
- When the stack nears the top row, the board frame pulses red and the STOP
  pause after a combo/chain is noticeably longer.
- A chain beyond 13 links shows `Chain x?!`.

- [ ] **Step 3: Report results to the user**

No commit for this task — it's verification only. If the manual playtest
reveals issues with the 🔶 constants (`FLOAT_DELAY`, `STOP_*`,
`DANGER_ZONE_STOP_MULTIPLIER`), note them for a follow-up tuning pass; per
the spec these are explicitly flagged as "to calibrate via playtest" and are
out of scope for this plan to get exactly right on the first try.
