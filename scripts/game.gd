extends Node2D

@onready var board: Node2D = $Board
@onready var score_label: Label = $ScoreLabel
@onready var chain_label: Label = $ChainLabel
@onready var game_over_panel: ColorRect = $GameOverPanel
@onready var restart_button: Button = $GameOverPanel/RestartButton

func _ready() -> void:
	board.score_changed.connect(_on_score_changed)
	board.chain_updated.connect(_on_chain_updated)
	board.game_over.connect(_on_game_over)
	restart_button.pressed.connect(_on_restart_pressed)
	game_over_panel.visible = false
	chain_label.text = ""

func _on_score_changed(new_score: int) -> void:
	score_label.text = "Score: %d" % new_score

func _on_chain_updated(chain: int) -> void:
	NeonTheme.animate_chain_label(chain_label, chain)

func _on_game_over() -> void:
	game_over_panel.visible = true

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()
