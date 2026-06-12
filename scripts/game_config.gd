extends Node

const SOURCE_KEYBOARD := "keyboard"
const SOURCE_GAMEPAD := "gamepad"

const SETTINGS_PATH := "user://settings.cfg"

# Canonical default keyboard layouts. Kept in sync with board.gd's
# KEYBOARD_SCHEME_1 / KEYBOARD_SCHEME_2 (those remain the runtime fallback).
const DEFAULT_KEYS_1 := {
	"left": KEY_A,
	"right": KEY_D,
	"up": KEY_W,
	"down": KEY_S,
	"swap": KEY_SPACE,
	"fast_rise": KEY_SHIFT,
}

const DEFAULT_KEYS_2 := {
	"left": KEY_LEFT,
	"right": KEY_RIGHT,
	"up": KEY_UP,
	"down": KEY_DOWN,
	"swap": KEY_ENTER,
	"fast_rise": KEY_CTRL,
}

var player1_source: String = SOURCE_KEYBOARD
var player1_device: int = 0
var player2_source: String = SOURCE_KEYBOARD
var player2_device: int = 0

var player1_keys: Dictionary = DEFAULT_KEYS_1.duplicate()
var player2_keys: Dictionary = DEFAULT_KEYS_2.duplicate()

var resolution: Vector2i = Vector2i(1600, 900)
var fullscreen: bool = false

func _ready() -> void:
	load_settings()
	apply_display()

func default_keys(player: int) -> Dictionary:
	return (DEFAULT_KEYS_1 if player == 1 else DEFAULT_KEYS_2).duplicate()

func apply_display() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(resolution)
		# Re-center on the current screen after resizing.
		var screen := DisplayServer.window_get_current_screen()
		var screen_size := DisplayServer.screen_get_size(screen)
		var pos := DisplayServer.screen_get_position(screen) + (screen_size - resolution) / 2
		DisplayServer.window_set_position(pos)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "resolution_x", resolution.x)
	cfg.set_value("display", "resolution_y", resolution.y)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("input", "player1_source", player1_source)
	cfg.set_value("input", "player1_device", player1_device)
	cfg.set_value("input", "player2_source", player2_source)
	cfg.set_value("input", "player2_device", player2_device)
	cfg.set_value("input", "player1_keys", player1_keys)
	cfg.set_value("input", "player2_keys", player2_keys)
	cfg.save(SETTINGS_PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	resolution = Vector2i(
		cfg.get_value("display", "resolution_x", resolution.x),
		cfg.get_value("display", "resolution_y", resolution.y)
	)
	fullscreen = cfg.get_value("display", "fullscreen", fullscreen)
	player1_source = cfg.get_value("input", "player1_source", player1_source)
	player1_device = cfg.get_value("input", "player1_device", player1_device)
	player2_source = cfg.get_value("input", "player2_source", player2_source)
	player2_device = cfg.get_value("input", "player2_device", player2_device)
	player1_keys = cfg.get_value("input", "player1_keys", player1_keys)
	player2_keys = cfg.get_value("input", "player2_keys", player2_keys)
