extends Node2D

@onready var player1_option: OptionButton = $Player1Option
@onready var player2_option: OptionButton = $Player2Option
@onready var start_button: Button = $StartButton

func _ready() -> void:
	_populate_options(player1_option)
	_populate_options(player2_option)
	start_button.pressed.connect(_on_start_pressed)

func _populate_options(option: OptionButton) -> void:
	option.clear()
	option.add_item("Clavier")
	for device in Input.get_connected_joypads():
		var device_id: int = device
		option.add_item("Manette %d" % (device_id + 1))
	option.selected = 0

func _on_start_pressed() -> void:
	_apply_selection(player1_option, true)
	_apply_selection(player2_option, false)
	get_tree().change_scene_to_file("res://scenes/Match.tscn")

func _apply_selection(option: OptionButton, is_player1: bool) -> void:
	var config: Node = get_node("/root/GameConfig")
	var index := option.selected
	var source: String = config.SOURCE_KEYBOARD if index == 0 else config.SOURCE_GAMEPAD
	var device := 0
	if index > 0:
		var joypads := Input.get_connected_joypads()
		device = joypads[index - 1]
	if is_player1:
		config.player1_source = source
		config.player1_device = device
	else:
		config.player2_source = source
		config.player2_device = device
