class_name NeonTheme
extends RefCounted

const BG_COLOR := Color(0.0392, 0.0392, 0.0784, 1.0)

const NEON_COLORS := [
	Color(1.0, 0.16, 0.35), # red/magenta
	Color(0.25, 1.0, 0.45), # green
	Color(0.25, 0.65, 1.0), # blue/cyan
	Color(1.0, 0.92, 0.25), # yellow
	Color(0.78, 0.35, 1.0), # purple
]

enum Shape { DIAMOND, CIRCLE, TRIANGLE, HEXAGON, STAR }

const SHAPES := [
	Shape.DIAMOND,
	Shape.CIRCLE,
	Shape.TRIANGLE,
	Shape.HEXAGON,
	Shape.STAR,
]

const CURSOR_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const CURSOR_OUTLINE_COLOR := Color(0.0, 0.0, 0.0, 0.65)


static func get_shape_points(shape: int, center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	match shape:
		Shape.DIAMOND:
			for i in range(4):
				var angle := -PI / 2.0 + i * (PI / 2.0)
				points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		Shape.CIRCLE:
			var sides := 24
			for i in range(sides):
				var angle := i * TAU / sides
				points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		Shape.TRIANGLE:
			for i in range(3):
				var angle := -PI / 2.0 + i * (TAU / 3.0)
				points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		Shape.HEXAGON:
			for i in range(6):
				var angle := -PI / 2.0 + i * (TAU / 6.0)
				points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		Shape.STAR:
			var spikes := 5
			for i in range(spikes * 2):
				var angle := -PI / 2.0 + i * (PI / spikes)
				var r := radius if i % 2 == 0 else radius * 0.45
				points.append(center + Vector2(cos(angle), sin(angle)) * r)
	return points


## Draws a shape with a soft "glow": several growing, fading outline passes
## under a solid filled shape on top.
static func draw_glow_shape(ci: CanvasItem, shape: int, center: Vector2, radius: float, color: Color, glow_layers: int = 4, base_width: float = 2.0) -> void:
	for i in range(glow_layers, 0, -1):
		var glow_alpha := color.a * (0.32 - i * 0.06)
		if glow_alpha <= 0.0:
			continue
		var glow_color := Color(color.r, color.g, color.b, glow_alpha)
		var glow_points := get_shape_points(shape, center, radius + i * 3.0)
		var loop := glow_points.duplicate()
		loop.append(glow_points[0])
		ci.draw_polyline(loop, glow_color, base_width + i * 2.5, true)

	var points := get_shape_points(shape, center, radius)
	ci.draw_colored_polygon(points, color)
	var outline := points.duplicate()
	outline.append(points[0])
	ci.draw_polyline(outline, color, base_width, true)


## Draws a glowing rectangle outline (used for the cursor and board frame).
static func draw_glow_rect_outline(ci: CanvasItem, rect: Rect2, color: Color, glow_layers: int = 4, base_width: float = 4.0) -> void:
	for i in range(glow_layers, 0, -1):
		var glow_alpha := color.a * (0.32 - i * 0.06)
		if glow_alpha <= 0.0:
			continue
		var glow_color := Color(color.r, color.g, color.b, glow_alpha)
		ci.draw_rect(rect.grow(i * 3.0), glow_color, false, base_width + i * 2.0)
	ci.draw_rect(rect, color, false, base_width)


## Draws diagonal hazard stripes across a rect (used for garbage blocks).
static func draw_hazard_stripes(ci: CanvasItem, rect: Rect2, stripe_color: Color, spacing: float = 16.0, thickness: float = 6.0) -> void:
	var diag := rect.size.y
	var x := rect.position.x - diag
	while x < rect.position.x + rect.size.x:
		ci.draw_line(
			Vector2(x, rect.position.y + rect.size.y),
			Vector2(x + diag, rect.position.y),
			stripe_color,
			thickness
		)
		x += spacing


const CHAIN_LABEL_DURATION := 1.0


## Shows a "Chain xN!" pop-in on the given label, with a scale bounce and a
## color escalation from yellow (low chains) to magenta (high chains), then
## clears the label after CHAIN_LABEL_DURATION (unless it changed again).
static func animate_chain_label(label: Label, chain: int) -> void:
	var label_text := "Chain x%d!" % chain
	label.text = label_text
	var t := clampf(float(chain - 2) / 6.0, 0.0, 1.0)
	label.modulate = Color.YELLOW.lerp(Color.MAGENTA, t)
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2(0.5, 0.5)

	var tween := label.create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2(1.3, 1.3), 0.15)
	tween.tween_property(label, "scale", Vector2(1, 1), 0.1)

	await label.get_tree().create_timer(CHAIN_LABEL_DURATION).timeout
	if label.text == label_text:
		label.text = ""
		label.scale = Vector2(1, 1)
		label.modulate = Color(1, 1, 1, 1)
