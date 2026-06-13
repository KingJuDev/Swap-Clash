extends CanvasLayer

## Global pause / system popup, opened with the "pause" action (Échap / Start).
## Autoloaded, so it overlays every scene. Options adapt to whether a match is
## currently running.

const MAIN_MENU := "res://scenes/MainMenu.tscn"
const PARTIE_SCENES := ["res://scenes/Match.tscn", "res://scenes/Game.tscn"]

@onready var _panel: Control = $Panel
@onready var _nav: Node = $Panel/MenuNav
@onready var _restart_button: Button = $Panel/VBox/RestartButton
@onready var _quit_to_menu_button: Button = $Panel/VBox/QuitToMenuButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.visible = false
	$Panel/VBox/BackButton.pressed.connect(close)
	_restart_button.pressed.connect(_on_restart)
	_quit_to_menu_button.pressed.connect(_on_quit_to_menu)
	$Panel/VBox/QuitGameButton.pressed.connect(_on_quit_game)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _panel.visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()

func open() -> void:
	var in_partie := _is_in_partie()
	_restart_button.visible = in_partie
	_quit_to_menu_button.visible = in_partie
	get_tree().paused = true
	_panel.visible = true
	_nav.refresh()

func close() -> void:
	_panel.visible = false
	get_tree().paused = false

func _is_in_partie() -> bool:
	var current := get_tree().current_scene
	return current != null and current.scene_file_path in PARTIE_SCENES

func _on_restart() -> void:
	get_tree().paused = false
	_panel.visible = false
	get_tree().reload_current_scene()

func _on_quit_to_menu() -> void:
	get_tree().paused = false
	_panel.visible = false
	get_tree().change_scene_to_file(MAIN_MENU)

func _on_quit_game() -> void:
	get_tree().quit()
