extends Node2D

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

@onready var resolution_option: OptionButton = $ResolutionOption
@onready var fullscreen_check: CheckButton = $FullscreenCheck
@onready var apply_button: Button = $ApplyButton
@onready var back_button: Button = $BackButton

func _ready() -> void:
	var config: Node = get_node("/root/GameConfig")
	resolution_option.clear()
	for i in RESOLUTIONS.size():
		var res := RESOLUTIONS[i]
		var label := "%d x %d" % [res.x, res.y]
		if res.y < 800:
			label += "  (plus petit)"
		resolution_option.add_item(label)
		if res == config.resolution:
			resolution_option.selected = i
	if resolution_option.selected < 0:
		resolution_option.selected = 0

	fullscreen_check.button_pressed = config.fullscreen

	apply_button.pressed.connect(_on_apply_pressed)
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/OptionsMenu.tscn"))

func _on_apply_pressed() -> void:
	var config: Node = get_node("/root/GameConfig")
	config.resolution = RESOLUTIONS[resolution_option.selected]
	config.fullscreen = fullscreen_check.button_pressed
	config.apply_display()
	config.save_settings()
