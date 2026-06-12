extends Node2D

# Renders a title string as a centered row of glowing neon "block" tiles (one
# per letter), echoing the game's colored blocks. Tiles gently bob up and down,
# out of phase, so the title feels alive. Fully procedural — no assets.

@export var title := "SWAP & CLASH"
@export var tile_size := 64.0
@export var gap := 10.0

const FILL_COLOR := Color(0.06, 0.06, 0.12, 0.92)
const LETTER_COLOR := Color(0.96, 0.98, 1.0, 1.0)
const LETTER_OUTLINE := Color(0.0, 0.0, 0.0, 0.9)
const AMP_COLOR := Color(1.0, 0.92, 0.25, 1.0) # yellow, for the "&"

const BOB_AMPLITUDE := 6.0
const BOB_SPEED := 2.2
const BOB_PHASE_STEP := 0.4

var _font: Font
var _time := 0.0

func _ready() -> void:
	_font = ThemeDB.fallback_font
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

# Lays out the visible glyphs (spaces just advance the cursor) and returns a list
# of { "ch", "x" (left edge), "amp" } plus the total row width for centering.
func _layout() -> Dictionary:
	var glyphs := []
	var cursor := 0.0
	var step := tile_size + gap
	for ch in title:
		if ch == " ":
			cursor += tile_size * 0.5
			continue
		glyphs.append({"ch": ch, "x": cursor, "amp": ch == "&"})
		cursor += step
	return {"glyphs": glyphs, "width": max(0.0, cursor - gap)}

func _draw() -> void:
	var layout := _layout()
	var glyphs: Array = layout["glyphs"]
	var x0 := -float(layout["width"]) / 2.0
	var font_size := int(tile_size * 0.6)

	for i in range(glyphs.size()):
		var g: Dictionary = glyphs[i]
		var bob: float = sin(_time * BOB_SPEED + i * BOB_PHASE_STEP) * BOB_AMPLITUDE
		var center := Vector2(x0 + g["x"] + tile_size / 2.0, bob)
		var color: Color = AMP_COLOR if g["amp"] else NeonTheme.NEON_COLORS[i % NeonTheme.NEON_COLORS.size()]
		var rect := Rect2(center - Vector2(tile_size, tile_size) / 2.0, Vector2(tile_size, tile_size))

		draw_rect(rect, FILL_COLOR, true)
		NeonTheme.draw_glow_rect_outline(self, rect, color, 3, 3.0)
		_draw_centered_letter(g["ch"], center, font_size)

func _draw_centered_letter(ch: String, center: Vector2, font_size: int) -> void:
	var text_size := _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := center.y + (_font.get_ascent(font_size) - _font.get_descent(font_size)) * 0.5
	var pos := Vector2(center.x - text_size.x / 2.0, baseline)
	draw_string_outline(_font, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, LETTER_OUTLINE)
	draw_string(_font, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, LETTER_COLOR)
