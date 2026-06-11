extends Node2D

@onready var board1: Node2D = $Board1
@onready var board2: Node2D = $Board2
@onready var score_label1: Label = $ScoreLabel1
@onready var score_label2: Label = $ScoreLabel2
@onready var garbage_label1: Label = $GarbageLabel1
@onready var garbage_label2: Label = $GarbageLabel2
@onready var end_panel: ColorRect = $EndPanel
@onready var end_label: Label = $EndPanel/EndLabel
@onready var restart_button: Button = $EndPanel/RestartButton

func _ready() -> void:
	var config: Node = get_node("/root/GameConfig")
	board1.input_source = config.player1_source
	board1.input_device = config.player1_device
	board1.keyboard_scheme = 1

	board2.input_source = config.player2_source
	board2.input_device = config.player2_device
	board2.keyboard_scheme = 2

	board1.score_changed.connect(func(s: int): score_label1.text = "Score: %d" % s)
	board2.score_changed.connect(func(s: int): score_label2.text = "Score: %d" % s)

	board1.garbage_sent.connect(board2.receive_garbage)
	board2.garbage_sent.connect(board1.receive_garbage)

	board1.game_over.connect(func(): _on_game_over(2))
	board2.game_over.connect(func(): _on_game_over(1))

	restart_button.pressed.connect(func(): get_tree().reload_current_scene())
	end_panel.visible = false

func _process(_delta: float) -> void:
	garbage_label1.text = "Garbage entrant: %d" % board1.pending_garbage.size()
	garbage_label2.text = "Garbage entrant: %d" % board2.pending_garbage.size()

func _on_game_over(winner: int) -> void:
	board1.set_process(false)
	board2.set_process(false)
	end_label.text = "Joueur %d gagne !" % winner
	end_panel.visible = true
