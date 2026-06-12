extends Node2D

@onready var easy_button: Button = $EasyButton
@onready var medium_button: Button = $MediumButton
@onready var hard_button: Button = $HardButton
@onready var back_button: Button = $BackButton

func _ready() -> void:
	easy_button.pressed.connect(_start.bind("facile"))
	medium_button.pressed.connect(_start.bind("moyen"))
	hard_button.pressed.connect(_start.bind("difficile"))
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ModeSelect.tscn"))

func _start(difficulty: String) -> void:
	var config: Node = get_node("/root/GameConfig")
	config.vs_cpu = true
	config.cpu_difficulty = difficulty
	config.save_settings()
	get_tree().change_scene_to_file("res://scenes/Match.tscn")
