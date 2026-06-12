extends Node2D

signal score_changed(new_score: int)
signal chain_updated(chain: int)
signal game_over
signal garbage_sent(pieces: Array)

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
const CONVERSION_FLASH_DURATION := 0.6
const CONVERSION_DURATION_PER_LAYER := 1.0
const FLOAT_DELAY := 0.2
const FALL_SPEED: float = CELL_SIZE / FALL_DURATION_PER_CELL

const RISE_SPEED_NORMAL := 6.0
const RISE_SPEED_FAST := 60.0
const MOVE_REPEAT_DELAY := 0.25
const MOVE_REPEAT_RATE := 0.06
const MAX_GARBAGE_HEIGHT := VISIBLE_ROWS - 1

const BOARD_FRAME_COLOR := Color(0.3, 0.7, 1.0)

const SHAKE_CHAIN_THRESHOLD := 3
const SHAKE_COMBO_THRESHOLD := 5

@export var input_device: int = 0

const JOY_AXIS_DEADZONE := 0.5

@export_enum("gamepad", "keyboard") var input_source: String = "gamepad"
@export var keyboard_scheme: int = 1

const KEYBOARD_SCHEME_1 := {
	"left": KEY_A,
	"right": KEY_D,
	"up": KEY_W,
	"down": KEY_S,
	"swap": KEY_SPACE,
	"fast_rise": KEY_SHIFT,
}

const KEYBOARD_SCHEME_2 := {
	"left": KEY_LEFT,
	"right": KEY_RIGHT,
	"up": KEY_UP,
	"down": KEY_DOWN,
	"swap": KEY_ENTER,
	"fast_rise": KEY_CTRL,
}

func _keyboard_keys() -> Dictionary:
	return KEYBOARD_SCHEME_2 if keyboard_scheme == 2 else KEYBOARD_SCHEME_1

@onready var cursor_node: ColorRect = $Cursor

# grid[row][col] -> Block or null. (0,0) is the top-left visible cell.
# Row TOTAL_ROWS - 1 is a hidden buffer row revealed when the stack rises.
var grid: Array = []

# cursor_pos.x = left column of the 2-wide cursor, cursor_pos.y = row.
var cursor_pos := Vector2i(GRID_WIDTH / 2 - 1, VISIBLE_ROWS - 1)
var rise_offset := 0.0
var score := 0
var chain_count := 0
var chain_max := 0
var combo_max := 0
var is_resolving := false
var game_over_flag := false
var incoming_garbage: Array = []
var _landed_this_frame: Array = []

var _swap_was_pressed := false
var _key_held_time := {}
var _base_position := Vector2.ZERO

func _ready() -> void:
	randomize()
	_base_position = position
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
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, Vector2(GRID_WIDTH * CELL_SIZE, VISIBLE_ROWS * CELL_SIZE))
	NeonTheme.draw_glow_rect_outline(self, rect, BOARD_FRAME_COLOR, 4, 3.0)

func _process(delta: float) -> void:
	if game_over_flag:
		return
	_update_incoming_garbage()
	_handle_cursor_movement(delta)

	var swap_pressed := _is_swap_pressed()
	if swap_pressed and not _swap_was_pressed and not is_resolving:
		_try_swap()
	_swap_was_pressed = swap_pressed

	if not is_resolving:
		var rise_speed := RISE_SPEED_FAST if _is_fast_rise_pressed() else RISE_SPEED_NORMAL
		rise_offset += rise_speed * delta
		while rise_offset >= CELL_SIZE:
			rise_offset -= CELL_SIZE
			_do_rise_step()
			if game_over_flag:
				break

	_update_visuals()

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

func _is_swap_pressed() -> bool:
	if input_source == "keyboard":
		var keycode := _keyboard_keys()["swap"] as Key
		return Input.is_physical_key_pressed(keycode)
	return Input.is_joy_button_pressed(input_device, JOY_BUTTON_A)

func _is_fast_rise_pressed() -> bool:
	if input_source == "keyboard":
		var keycode := _keyboard_keys()["fast_rise"] as Key
		return Input.is_physical_key_pressed(keycode)
	return Input.is_joy_button_pressed(input_device, JOY_BUTTON_B)

func _is_direction_pressed(dir_name: String) -> bool:
	if input_source == "keyboard":
		var keycode := _keyboard_keys()[dir_name] as Key
		return Input.is_physical_key_pressed(keycode)
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
	chain_max = 0
	await _apply_gravity()
	await _resolve_matches()
	is_resolving = false

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

func _advance_simulation(delta: float) -> void:
	_update_blocks(delta)
	_update_garbage_blocks(delta)
	_check_matches()
	if _is_board_settled() and chain_max > 0:
		_end_chain()

func _resolve_matches() -> void:
	var matches := _find_matches()
	if matches.is_empty():
		if chain_max >= 2:
			var h: int = min(chain_max - 1, MAX_GARBAGE_HEIGHT)
			garbage_sent.emit([{"w": GRID_WIDTH, "h": h}])
		chain_count = 0
		chain_max = 0
		return

	chain_count += 1
	chain_max = max(chain_max, chain_count)
	var combo_size := matches.size()
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
		_convert_garbage_block(g)

	await _apply_gravity()
	await _resolve_matches()

func receive_garbage(pieces: Array) -> void:
	for piece in pieces:
		incoming_garbage.append(piece)

func _update_incoming_garbage() -> void:
	if incoming_garbage.is_empty() or is_resolving:
		return
	var piece: Dictionary = incoming_garbage[0]
	var w: int = piece.w
	var h: int = piece.h
	var c0: int = 0 if w >= GRID_WIDTH else randi() % (GRID_WIDTH - w + 1)
	for row in range(h):
		for col in range(c0, c0 + w):
			if grid[row][col] != null:
				return
	_spawn_garbage_block(Vector2i(c0, 0), w, h)
	incoming_garbage.remove_at(0)
	_settle_after_garbage_arrival()

## Newly-arrived garbage spawns at the top of the board; without this it
## would float there until the player's next swap triggered gravity.
func _settle_after_garbage_arrival() -> void:
	is_resolving = true
	await _apply_gravity()
	is_resolving = false

func _convert_garbage_block(g: GarbageBlock) -> void:
	g.play_match_flash()
	await get_tree().create_timer(CONVERSION_FLASH_DURATION).timeout
	while g.height > 0:
		var bottom_row := g.origin.y + g.height - 1
		for col in range(g.origin.x, g.origin.x + g.width):
			grid[bottom_row][col] = _spawn_block(randi() % NUM_COLORS, bottom_row, col)
		g.play_shatter_row(g.height - 1, CELL_SIZE)
		g.height -= 1
		var fully_converted := g.height <= 0
		if fully_converted:
			g.queue_free()
		else:
			g.shrink_to(g.height, CELL_SIZE)
		await get_tree().create_timer(CONVERSION_DURATION_PER_LAYER).timeout
		if not is_resolving:
			is_resolving = true
			await _apply_gravity()
			await _resolve_matches()
			is_resolving = false
		if fully_converted:
			break

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

func _score_for(combo_size: int, chain: int) -> int:
	var base_score := 10 * combo_size
	if combo_size > 3:
		base_score += (combo_size - 3) * 20
	return base_score * chain

func _garbage_combo_pieces(combo_size: int) -> Array:
	if combo_size < 4:
		return []
	var w: int = combo_size - 1
	var num_pieces: int = int(ceil(w / float(GRID_WIDTH)))
	var base: int = w / num_pieces
	var remainder: int = w % num_pieces
	var pieces := []
	for i in range(num_pieces):
		var piece_w: int = base + (1 if i < remainder else 0)
		pieces.append({"w": piece_w, "h": 1})
	return pieces

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
	shake(14.0, 0.4)
	game_over.emit()

func shake(intensity: float = 8.0, duration: float = 0.25) -> void:
	var tween := create_tween()
	tween.tween_method(_apply_shake_offset.bind(intensity), 0.0, 1.0, duration)
	tween.tween_callback(func(): position = _base_position)

func _apply_shake_offset(t: float, intensity: float) -> void:
	var amount := intensity * (1.0 - t)
	position = _base_position + Vector2(randf_range(-amount, amount), randf_range(-amount, amount))

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
