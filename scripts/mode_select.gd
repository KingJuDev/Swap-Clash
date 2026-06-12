extends Node2D

@onready var versus_button: Button = $VersusButton
@onready var cpu_button: Button = $CpuButton
@onready var back_button: Button = $BackButton

func _ready() -> void:
	versus_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Match.tscn"))
	# Joueur vs Ordinateur : à venir.
	cpu_button.disabled = true
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
