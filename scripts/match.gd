extends Node2D

@onready var board1: Node2D = $Board1
@onready var board2: Node2D = $Board2
@onready var score_label1: Label = $ScorePanel1/ScoreLabel1
@onready var score_label2: Label = $ScorePanel2/ScoreLabel2
@onready var garbage_label1: Label = $GarbagePanel1/GarbageLabel1
@onready var garbage_label2: Label = $GarbagePanel2/GarbageLabel2
@onready var chain_label1: Label = $ChainLabel1
@onready var chain_label2: Label = $ChainLabel2
@onready var end_panel: ColorRect = $EndPanel
@onready var end_label: Label = $EndPanel/EndLabel
@onready var restart_button: Button = $EndPanel/RestartButton

var _vs_cpu := false

func _ready() -> void:
	var config: Node = get_node("/root/GameConfig")
	_vs_cpu = config.vs_cpu
	board1.input_source = config.player1_source
	board1.input_device = config.player1_device
	board1.keyboard_scheme = 1

	if config.vs_cpu:
		board2.input_source = "ai"
		board2.ai = AIController.new(config.cpu_difficulty)
	else:
		board2.input_source = config.player2_source
		board2.input_device = config.player2_device
	board2.keyboard_scheme = 2

	board1.score_changed.connect(func(s: int): score_label1.text = "Score: %d" % s)
	board2.score_changed.connect(func(s: int): score_label2.text = "Score: %d" % s)

	board1.chain_updated.connect(func(chain: int): NeonTheme.animate_chain_label(chain_label1, chain))
	board2.chain_updated.connect(func(chain: int): NeonTheme.animate_chain_label(chain_label2, chain))

	board1.garbage_sent.connect(board2.receive_garbage)
	board2.garbage_sent.connect(board1.receive_garbage)

	board1.game_over.connect(func(): _on_game_over(2))
	board2.game_over.connect(func(): _on_game_over(1))

	restart_button.pressed.connect(func(): get_tree().reload_current_scene())
	end_panel.visible = false

	var music := get_node_or_null("/root/MusicPlayer")
	if music != null:
		music.play_battle()

func _process(_delta: float) -> void:
	garbage_label1.text = "Garbage entrant: %d" % board1.incoming_garbage.size()
	garbage_label2.text = "Garbage entrant: %d" % board2.incoming_garbage.size()

func _on_game_over(winner: int) -> void:
	board1.set_process(false)
	board2.set_process(false)
	if _vs_cpu:
		end_label.text = "Vous gagnez !" if winner == 1 else "L'ordinateur gagne !"
	else:
		end_label.text = "Joueur %d gagne !" % winner
	end_panel.visible = true
