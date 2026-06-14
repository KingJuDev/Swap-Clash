extends Node2D

@onready var play_button: Button = $PlayButton
@onready var options_button: Button = $OptionsButton

func _ready() -> void:
	var music := get_node_or_null("/root/MusicPlayer")
	if music != null:
		music.stop()

	play_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ModeSelect.tscn"))
	options_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/OptionsMenu.tscn"))
