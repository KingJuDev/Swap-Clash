class_name GarbageBlock
extends ColorRect

enum State { IDLE, FLOATING, FALLING, FLASHING }

const GARBAGE_COLOR := Color(0.4, 0.4, 0.4)
const GRID_LINE_COLOR := Color(0.05, 0.05, 0.08, 0.6)
const HAZARD_STRIPE_COLOR := Color(1.0, 1.0, 1.0, 0.15)
const GLOW_COLOR := Color(0.85, 0.9, 1.0)

var width: int = 1
var height: int = 1
var origin: Vector2i = Vector2i.ZERO
var state: State = State.IDLE
var float_timer: float = 0.0

var _cell_size: int = 64

func setup(w: int, h: int, cell_size: int) -> void:
	width = w
	height = h
	_cell_size = cell_size
	color = GARBAGE_COLOR
	size = Vector2(w * cell_size, h * cell_size)
	clip_contents = true
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	NeonTheme.draw_hazard_stripes(self, rect, HAZARD_STRIPE_COLOR)
	for c in range(1, width):
		draw_line(Vector2(c * _cell_size, 0), Vector2(c * _cell_size, height * _cell_size), GRID_LINE_COLOR, 1.0)
	for r in range(1, height):
		draw_line(Vector2(0, r * _cell_size), Vector2(width * _cell_size, r * _cell_size), GRID_LINE_COLOR, 1.0)
	NeonTheme.draw_glow_rect_outline(self, rect, GLOW_COLOR, 3, 3.0)

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

## Spawns small fragments flying away from the destroyed row, as a sibling
## of this block (so they survive shrink_to/queue_free).
func play_shatter_row(row_index: int, cell_size: int) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var row_y := position.y + row_index * cell_size
	for col in range(width):
		var cell_x := position.x + col * cell_size
		for i in range(4):
			var frag := ColorRect.new()
			frag.color = GLOW_COLOR
			frag.mouse_filter = Control.MOUSE_FILTER_IGNORE
			frag.size = Vector2(cell_size / 4.0, cell_size / 4.0)
			frag.position = Vector2(cell_x + cell_size / 2.0, row_y + cell_size / 2.0)
			parent.add_child(frag)

			var dir := Vector2(randf_range(-1.0, 1.0), randf_range(-1.4, -0.2)).normalized()
			var dist := randf_range(20.0, 50.0)
			var tween := frag.create_tween()
			tween.set_parallel(true)
			tween.tween_property(frag, "position", frag.position + dir * dist, 0.3)
			tween.tween_property(frag, "modulate:a", 0.0, 0.3)
			tween.tween_property(frag, "rotation", randf_range(-PI, PI), 0.3)
			tween.chain().tween_callback(frag.queue_free)
