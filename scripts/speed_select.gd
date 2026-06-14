extends Node2D

const MIN_LEVEL := 1
const MAX_LEVEL := 9

@onready var value_label: Label = $ValueLabel
@onready var minus_button: Button = $MinusButton
@onready var plus_button: Button = $PlusButton
@onready var start_button: Button = $StartButton
@onready var back_button: Button = $BackButton

var _level := 5

func _ready() -> void:
	var config: Node = get_node("/root/GameConfig")
	_level = clampi(config.rise_level, MIN_LEVEL, MAX_LEVEL)
	_update_label()

	minus_button.pressed.connect(_change.bind(-1))
	plus_button.pressed.connect(_change.bind(1))
	start_button.pressed.connect(_on_start)
	back_button.pressed.connect(_on_back)

# Left/right adjust the value. MenuNav (vertical_only) leaves these unbound, so
# the events reach here instead of moving focus.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		_change(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_change(1)
		get_viewport().set_input_as_handled()

func _change(delta: int) -> void:
	_level = clampi(_level + delta, MIN_LEVEL, MAX_LEVEL)
	_update_label()

func _update_label() -> void:
	value_label.text = str(_level)

func _on_start() -> void:
	var config: Node = get_node("/root/GameConfig")
	config.rise_level = _level
	config.save_settings()
	get_tree().change_scene_to_file("res://scenes/Match.tscn")

func _on_back() -> void:
	var config: Node = get_node("/root/GameConfig")
	if config.vs_cpu:
		get_tree().change_scene_to_file("res://scenes/CpuDifficulty.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ModeSelect.tscn")
