extends ColorRect

# Animated neon backdrop for the menu screens: a dark vertical gradient, a faint
# grid, and a handful of softly glowing shapes drifting slowly upward. Kept at
# low opacity so it never competes with the UI on top.

const GRID_COLOR := Color(1.0, 1.0, 1.0, 0.03)
const GRID_SPACING := 32.0

const TOP_COLOR := Color(0.055, 0.06, 0.12, 1.0)
const BOTTOM_COLOR := Color(0.016, 0.016, 0.035, 1.0)

const SHAPE_COUNT := 14
const SHAPE_MIN_RADIUS := 18.0
const SHAPE_MAX_RADIUS := 46.0
const SHAPE_MIN_ALPHA := 0.10
const SHAPE_MAX_ALPHA := 0.18
const RISE_MIN := 8.0
const RISE_MAX := 22.0
const SWAY_AMPLITUDE := 14.0
const SWAY_SPEED := 0.6

var _shapes: Array = []
var _time := 0.0

func _ready() -> void:
	color = BOTTOM_COLOR
	_spawn_shapes()
	set_process(true)
	queue_redraw()

func _spawn_shapes() -> void:
	_shapes.clear()
	for i in range(SHAPE_COUNT):
		var idx := randi() % NeonTheme.SHAPES.size()
		var base: Color = NeonTheme.NEON_COLORS[randi() % NeonTheme.NEON_COLORS.size()]
		var alpha := randf_range(SHAPE_MIN_ALPHA, SHAPE_MAX_ALPHA)
		_shapes.append({
			"pos": Vector2(randf_range(0.0, size.x), randf_range(0.0, size.y)),
			"rise": randf_range(RISE_MIN, RISE_MAX),
			"shape": NeonTheme.SHAPES[idx],
			"color": Color(base.r, base.g, base.b, alpha),
			"radius": randf_range(SHAPE_MIN_RADIUS, SHAPE_MAX_RADIUS),
			"phase": randf_range(0.0, TAU),
		})

func _process(delta: float) -> void:
	_time += delta
	for s in _shapes:
		s["pos"].y -= s["rise"] * delta
		if s["pos"].y < -s["radius"] - 60.0:
			s["pos"].y = size.y + s["radius"] + 60.0
			s["pos"].x = randf_range(0.0, size.x)
	queue_redraw()

func _draw() -> void:
	# Vertical gradient via a full-screen quad with per-vertex colors.
	var quad := PackedVector2Array([
		Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y)
	])
	var colors := PackedColorArray([TOP_COLOR, TOP_COLOR, BOTTOM_COLOR, BOTTOM_COLOR])
	draw_polygon(quad, colors)

	# Faint grid.
	var x := 0.0
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), GRID_COLOR, 1.0)
		x += GRID_SPACING
	var y := 0.0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), GRID_COLOR, 1.0)
		y += GRID_SPACING

	# Drifting glow shapes (with a gentle horizontal sway).
	for s in _shapes:
		var sway: float = sin(_time * SWAY_SPEED + s["phase"]) * SWAY_AMPLITUDE
		var center: Vector2 = s["pos"] + Vector2(sway, 0.0)
		NeonTheme.draw_glow_shape(self, s["shape"], center, s["radius"], s["color"])
