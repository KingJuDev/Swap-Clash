extends SceneTree

const MainMenuScene := preload("res://scenes/MainMenu.tscn")
const OptionsScene := preload("res://scenes/OptionsMenu.tscn")

var _step := 0
var _menu: Variant = null
var _options: Variant = null

func _initialize() -> void:
	_menu = MainMenuScene.instantiate()
	get_root().add_child(_menu)

func _process(_delta: float) -> bool:
	match _step:
		0:
			# First button receives focus on load.
			assert(_menu.play_button.has_focus())
			# Directional focus neighbors are wired (Node2D root has no auto-search).
			assert(_menu.play_button.find_valid_focus_neighbor(SIDE_BOTTOM) == _menu.options_button)
			assert(_menu.play_button.find_valid_focus_neighbor(SIDE_TOP) == _menu.options_button)
			# Mouse hover mirrors focus (keyboard/mouse mode).
			_menu.options_button.mouse_entered.emit()
			assert(_menu.options_button.has_focus())
			_menu.queue_free()
			_step = 1
			return false
		1:
			_options = OptionsScene.instantiate()
			get_root().add_child(_options)
			_step = 2
			return false
		2:
			var nav: Variant = _options.get_node("MenuNav")
			# MenuNav located the BackButton for the cancel action.
			assert(nav._back_button == _options.back_button)
			var fired := [false]
			_options.back_button.pressed.connect(func(): fired[0] = true)
			var event := InputEventAction.new()
			event.action = "ui_cancel"
			event.pressed = true
			nav._unhandled_input(event)
			assert(fired[0])
			print("ALL TESTS PASSED")
			quit()
	return false
