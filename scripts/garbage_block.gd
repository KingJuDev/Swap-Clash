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
