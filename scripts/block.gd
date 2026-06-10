class_name Block
extends ColorRect

enum State { IDLE, SWAPPING, FALLING, MATCHED, CLEARING }

const COLORS := [
	Color(0.90, 0.20, 0.20), # red
	Color(0.20, 0.75, 0.30), # green
	Color(0.25, 0.45, 0.95), # blue
	Color(0.95, 0.85, 0.20), # yellow
	Color(0.65, 0.30, 0.90), # purple
]

var color_id: int = 0
var state: State = State.IDLE
var grid_pos: Vector2i = Vector2i.ZERO

func set_color_id(id: int) -> void:
	color_id = id
	color = COLORS[id]

func play_swap(target_pos: Vector2, duration: float) -> void:
	state = State.SWAPPING
	var tween := create_tween()
	tween.tween_property(self, "position", target_pos, duration)
	tween.finished.connect(func(): state = State.IDLE)

func play_fall(target_pos: Vector2, duration: float) -> void:
	state = State.FALLING
	var tween := create_tween()
	tween.tween_property(self, "position", target_pos, duration)
	tween.finished.connect(func(): state = State.IDLE)

func play_match_flash() -> void:
	state = State.MATCHED
	var tween := create_tween()
	tween.set_loops(4)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0.25), 0.08)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.08)

func play_clear() -> void:
	state = State.CLEARING
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
