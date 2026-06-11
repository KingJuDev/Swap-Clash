extends Node2D

signal score_changed(new_score: int)
signal chain_updated(chain: int)
signal game_over
signal garbage_sent(power: int)

const BlockScene := preload("res://scenes/Block.tscn")
const GarbageBlockScene := preload("res://scenes/GarbageBlock.tscn")

const GRID_WIDTH := 6
const VISIBLE_ROWS := 12
const TOTAL_ROWS := VISIBLE_ROWS + 1 # last row is the hidden buffer row
const CELL_SIZE := 64
const NUM_COLORS := 5

const SWAP_DURATION := 0.08
const FALL_DURATION_PER_CELL := 0.06
const FLASH_DURATION := 0.32
const CLEAR_DURATION := 0.15

const RISE_SPEED_NORMAL := 6.0
const RISE_SPEED_FAST := 60.0
const MOVE_REPEAT_DELAY := 0.25
const MOVE_REPEAT_RATE := 0.06
const TELEGRAPH_DURATION := 2.0
const MAX_GARBAGE_HEIGHT := VISIBLE_ROWS - 1

@onready var cursor_node: ColorRect = $Cursor

# grid[row][col] -> Block or null. (0,0) is the top-left visible cell.
# Row TOTAL_ROWS - 1 is a hidden buffer row revealed when the stack rises.
var grid: Array = []

# cursor_pos.x = left column of the 2-wide cursor, cursor_pos.y = row.
var cursor_pos := Vector2i(GRID_WIDTH / 2 - 1, VISIBLE_ROWS - 1)
var rise_offset := 0.0
var score := 0
var chain_count := 0
var is_resolving := false
var game_over_flag := false

var _space_was_pressed := false
var _key_held_time := {}

func _ready() -> void:
	randomize()
	for row in range(TOTAL_ROWS):
		var cells := []
		for col in range(GRID_WIDTH):
			cells.append(null)
		grid.append(cells)
	var start_row := VISIBLE_ROWS - 6
	for row in range(start_row, TOTAL_ROWS):
		var colors := _generate_row(row)
		for col in range(GRID_WIDTH):
			grid[row][col] = _spawn_block(colors[col], row, col)
	_update_visuals()

func _process(delta: float) -> void:
	if game_over_flag:
		return
	_handle_cursor_movement(delta)

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

	_update_visuals()

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

func _move_cursor(dir: Vector2i) -> void:
	var new_pos := cursor_pos + dir
	new_pos.x = clampi(new_pos.x, 0, GRID_WIDTH - 2)
	new_pos.y = clampi(new_pos.y, 0, VISIBLE_ROWS - 1)
	cursor_pos = new_pos

func _try_swap() -> void:
	var col1 := cursor_pos.x
	var col2 := col1 + 1
	var row := cursor_pos.y
	var b1: Variant = grid[row][col1]
	var b2: Variant = grid[row][col2]
	if b1 == null and b2 == null:
		return
	if (b1 != null and b1.state != Block.State.IDLE) or (b2 != null and b2.state != Block.State.IDLE):
		return

	grid[row][col1] = b2
	grid[row][col2] = b1
	if b1 != null:
		b1.grid_pos = Vector2i(col2, row)
		b1.play_swap(_cell_position(col2, row), SWAP_DURATION)
	if b2 != null:
		b2.grid_pos = Vector2i(col1, row)
		b2.play_swap(_cell_position(col1, row), SWAP_DURATION)

	is_resolving = true
	await get_tree().create_timer(SWAP_DURATION).timeout
	chain_count = 0
	await _apply_gravity()
	await _resolve_matches()
	is_resolving = false

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
		var p: Vector2i = pos
		for dir in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var n: Vector2i = p + dir
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

func _find_matches() -> Array:
	var matched := {}

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

	return matched.keys()

func _score_for(combo_size: int, chain: int) -> int:
	var base_score := 10 * combo_size
	if combo_size > 3:
		base_score += (combo_size - 3) * 20
	return base_score * chain

func _garbage_power_for(combo_size: int, chain: int) -> int:
	if chain >= 2:
		var height: int = min(chain - 1, 12)
		return 6 * height
	if combo_size >= 4:
		return min(combo_size - 1, 6)
	return 0

func _garbage_shape_for_power(power: int) -> Dictionary:
	if power <= 0:
		return {"height": 0, "width": 0}
	if power <= GRID_WIDTH:
		return {"height": 1, "width": power}
	var height: int = int(ceil(power / float(GRID_WIDTH)))
	height = min(height, MAX_GARBAGE_HEIGHT)
	return {"height": height, "width": GRID_WIDTH}

func _generate_row(row_index: int) -> Array:
	var row_colors := []
	for col in range(GRID_WIDTH):
		var forbidden := []
		if col >= 2 and row_colors[col - 1] == row_colors[col - 2]:
			forbidden.append(row_colors[col - 1])
		if row_index >= 2:
			var above1: Variant = grid[row_index - 1][col]
			var above2: Variant = grid[row_index - 2][col]
			if above1 is Block and above2 is Block and above1.color_id == above2.color_id:
				forbidden.append(above1.color_id)
		var choices := []
		for c in range(NUM_COLORS):
			if not forbidden.has(c):
				choices.append(c)
		row_colors.append(choices[randi() % choices.size()])
	return row_colors

func _do_rise_step() -> void:
	for col in range(GRID_WIDTH):
		if grid[0][col] != null:
			_trigger_game_over()
			return

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

	var new_colors := _generate_row(TOTAL_ROWS - 1)
	var new_row := []
	for col in range(GRID_WIDTH):
		new_row.append(_spawn_block(new_colors[col], TOTAL_ROWS - 1, col))
	grid[TOTAL_ROWS - 1] = new_row

func _trigger_game_over() -> void:
	game_over_flag = true
	game_over.emit()

func _spawn_block(color_id: int, row: int, col: int) -> Block:
	var b := BlockScene.instantiate() as Block
	add_child(b)
	b.set_color_id(color_id)
	b.grid_pos = Vector2i(col, row)
	b.position = _cell_position(col, row)
	return b

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

func _cell_position(col: int, row: int) -> Vector2:
	return Vector2(col * CELL_SIZE, row * CELL_SIZE - rise_offset)

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
