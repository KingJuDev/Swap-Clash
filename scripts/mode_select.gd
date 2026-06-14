extends Node2D

@onready var versus_button: Button = $VersusButton
@onready var cpu_button: Button = $CpuButton
@onready var back_button: Button = $BackButton

func _ready() -> void:
	versus_button.pressed.connect(_on_versus_pressed)
	cpu_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/CpuDifficulty.tscn"))
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))

func _on_versus_pressed() -> void:
	var config: Node = get_node("/root/GameConfig")
	config.vs_cpu = false
	get_tree().change_scene_to_file("res://scenes/SpeedSelect.tscn")
