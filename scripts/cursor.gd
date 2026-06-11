class_name BoardCursor
extends ColorRect

var _pulse_alpha := 1.0

func _ready() -> void:
	color = Color(1, 1, 1, 0)
	# Blocks are added as later siblings at runtime, which would otherwise
	# draw on top of (and hide) the cursor.
	z_index = 10
	var tween := create_tween()
	tween.set_loops()
	tween.tween_method(_set_pulse, 1.0, 0.5, 0.5)
	tween.tween_method(_set_pulse, 0.5, 1.0, 0.5)

func _set_pulse(value: float) -> void:
	_pulse_alpha = value
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	# Dark outline behind the white glow keeps the cursor readable even
	# against light blocks (e.g. the yellow hexagon).
	NeonTheme.draw_glow_rect_outline(self, rect.grow(2.0), NeonTheme.CURSOR_OUTLINE_COLOR, 1, 3.0)
	var pulse_color := Color(NeonTheme.CURSOR_COLOR.r, NeonTheme.CURSOR_COLOR.g, NeonTheme.CURSOR_COLOR.b, _pulse_alpha)
	NeonTheme.draw_glow_rect_outline(self, rect, pulse_color, 3, 5.0)
