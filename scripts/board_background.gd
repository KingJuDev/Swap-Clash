extends ColorRect

const GRID_COLOR := Color(1.0, 1.0, 1.0, 0.03)
const GRID_SPACING := 32.0

func _ready() -> void:
	color = NeonTheme.BG_COLOR
	queue_redraw()

func _draw() -> void:
	var x := 0.0
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), GRID_COLOR, 1.0)
		x += GRID_SPACING
	var y := 0.0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), GRID_COLOR, 1.0)
		y += GRID_SPACING
