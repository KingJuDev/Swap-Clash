extends Node2D

const ACTIONS: Array[String] = ["left", "right", "up", "down", "swap", "fast_rise"]
const ACTION_LABELS := {
	"left": "Gauche",
	"right": "Droite",
	"up": "Haut",
	"down": "Bas",
	"swap": "Échanger",
	"fast_rise": "Montée rapide",
}

@onready var player1_device: OptionButton = $Player1Device
@onready var player2_device: OptionButton = $Player2Device
@onready var back_button: Button = $BackButton

# {"player": int, "action": String, "button": Button} while capturing a key, else {}.
var _remapping: Dictionary = {}

func _ready() -> void:
	var config: Node = get_node("/root/GameConfig")

	_populate_device(player1_device, config.player1_source, config.player1_device)
	_populate_device(player2_device, config.player2_source, config.player2_device)
	player1_device.item_selected.connect(func(_i): _on_device_selected(1))
	player2_device.item_selected.connect(func(_i): _on_device_selected(2))

	for player in [1, 2]:
		for action in ACTIONS:
			var button := _remap_button(player, action)
			button.pressed.connect(_on_remap_pressed.bind(player, action, button))
	_refresh_all_labels()
	_refresh_remap_enabled()

	back_button.pressed.connect(_on_back_pressed)

func _remap_button(player: int, action: String) -> Button:
	return get_node("P%dBtn_%s" % [player, action])

func _player_keys(player: int) -> Dictionary:
	var config: Node = get_node("/root/GameConfig")
	return config.player1_keys if player == 1 else config.player2_keys

func _populate_device(option: OptionButton, source: String, device: int) -> void:
	option.clear()
	option.add_item("Clavier")
	var joypads := Input.get_connected_joypads()
	for d in joypads:
		option.add_item("Manette %d" % (int(d) + 1))
	var selected := 0
	if source == "gamepad":
		var idx := joypads.find(device)
		if idx >= 0:
			selected = idx + 1
	option.selected = selected

func _on_device_selected(player: int) -> void:
	var config: Node = get_node("/root/GameConfig")
	var option: OptionButton = player1_device if player == 1 else player2_device
	var index := option.selected
	var source: String = config.SOURCE_KEYBOARD if index == 0 else config.SOURCE_GAMEPAD
	var device := 0
	if index > 0:
		var joypads := Input.get_connected_joypads()
		device = joypads[index - 1]
	if player == 1:
		config.player1_source = source
		config.player1_device = device
	else:
		config.player2_source = source
		config.player2_device = device
	_refresh_remap_enabled()

func _on_remap_pressed(player: int, action: String, button: Button) -> void:
	# Cancel any in-progress capture first.
	if not _remapping.is_empty():
		_refresh_label(_remapping["player"], _remapping["action"])
	_remapping = {"player": player, "action": action, "button": button}
	button.text = "%s : ..." % ACTION_LABELS[action]

func _unhandled_input(event: InputEvent) -> void:
	if _remapping.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var player: int = _remapping["player"]
		var action: String = _remapping["action"]
		_player_keys(player)[action] = event.physical_keycode
		_remapping = {}
		_refresh_label(player, action)
		get_viewport().set_input_as_handled()

func _refresh_all_labels() -> void:
	for player in [1, 2]:
		for action in ACTIONS:
			_refresh_label(player, action)

func _refresh_label(player: int, action: String) -> void:
	var keycode: int = _player_keys(player).get(action, 0)
	var key_name := OS.get_keycode_string(keycode) if keycode != 0 else "—"
	_remap_button(player, action).text = "%s : %s" % [ACTION_LABELS[action], key_name]

func _refresh_remap_enabled() -> void:
	var config: Node = get_node("/root/GameConfig")
	for player in [1, 2]:
		var is_keyboard: bool = (config.player1_source if player == 1 else config.player2_source) == config.SOURCE_KEYBOARD
		for action in ACTIONS:
			_remap_button(player, action).disabled = not is_keyboard

func _on_back_pressed() -> void:
	var config: Node = get_node("/root/GameConfig")
	config.save_settings()
	get_tree().change_scene_to_file("res://scenes/OptionsMenu.tscn")
