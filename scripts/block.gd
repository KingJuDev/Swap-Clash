class_name Block
extends ColorRect

enum State { IDLE, SWAPPING, FLOATING, FALLING, MATCHED, CLEARING }

const COLORS := NeonTheme.NEON_COLORS
const SHAPES := NeonTheme.SHAPES

const FLASH_OVERBRIGHT := Color(1.6, 1.6, 1.6, 1.0)
const CLEAR_DURATION := 0.15

var color_id: int = 0
var state: State = State.IDLE
var grid_pos: Vector2i = Vector2i.ZERO
var from_chain: bool = false
var float_timer: float = 0.0
var state_timer: float = 0.0

func _ready() -> void:
	pivot_offset = size / 2.0

func _draw() -> void:
	var center := size / 2.0
	var radius := size.x * 0.32
	NeonTheme.draw_glow_shape(self, SHAPES[color_id], center, radius, COLORS[color_id])

func set_color_id(id: int) -> void:
	color_id = id
	queue_redraw()

func play_swap(target_pos: Vector2, duration: float) -> void:
	state = State.SWAPPING
	var tween := create_tween()
	tween.tween_property(self, "position", target_pos, duration)
	tween.finished.connect(func(): state = State.IDLE)

	var squash := create_tween()
	squash.tween_property(self, "scale", Vector2(1.15, 0.85), duration * 0.5)
	squash.tween_property(self, "scale", Vector2(1, 1), duration * 0.5)

func play_land_squash() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.25, 0.75), 0.05)
	tween.tween_property(self, "scale", Vector2(1, 1), 0.08)

func play_match_flash() -> void:
	state = State.MATCHED
	var tween := create_tween()
	tween.set_loops(2)
	tween.tween_property(self, "modulate", FLASH_OVERBRIGHT, 0.08)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.08)

	var pop := create_tween()
	pop.tween_property(self, "scale", Vector2(1.3, 1.3), 0.08)
	pop.tween_property(self, "scale", Vector2(1, 1), 0.08)

func play_clear() -> void:
	state = State.CLEARING
	_spawn_clear_particles()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, CLEAR_DURATION)
	tween.tween_property(self, "scale", Vector2(0.1, 0.1), CLEAR_DURATION)

func _spawn_clear_particles() -> void:
	var particles := CPUParticles2D.new()
	get_parent().add_child(particles)
	particles.global_position = global_position + size / 2.0
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 12
	particles.lifetime = 0.4
	particles.direction = Vector2(0, -1)
	particles.spread = 180.0
	particles.initial_velocity_min = 60.0
	particles.initial_velocity_max = 140.0
	particles.gravity = Vector2(0, 400)
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = COLORS[color_id]

	await get_tree().create_timer(particles.lifetime + 0.1).timeout
	particles.queue_free()
