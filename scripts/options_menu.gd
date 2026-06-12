extends Node2D

@onready var resolution_button: Button = $ResolutionButton
@onready var controls_button: Button = $ControlsButton
@onready var back_button: Button = $BackButton

func _ready() -> void:
	resolution_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ResolutionOptions.tscn"))
	controls_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ControlsOptions.tscn"))
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
