# Menu de configuration des entrées (clavier/manette) - Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permettre à chaque joueur de choisir clavier ou manette via un écran de menu avant la partie, et ajouter un mapping clavier complet (sans pavé numérique) pour pouvoir jouer à 2 sur un seul clavier.

**Architecture:**
- `Board` (`board.gd`) gagne un `input_source` ("keyboard"/"gamepad") et un `keyboard_scheme` (1 ou 2), avec deux jeux de touches prédéfinis.
- Un nouveau singleton autoload `GameConfig` stocke le choix de périphérique de chaque joueur, partagé entre la scène de menu et `Match`.
- Une nouvelle scène `SetupMenu.tscn` (nouvelle scène principale) laisse chaque joueur choisir "Clavier" ou "Manette N" (manettes détectées dynamiquement), puis lance `Match.tscn`.
- `Match.tscn`/`match.gd` perdent l'écran "En attente de manettes" (la partie peut toujours démarrer au clavier) et appliquent la config de `GameConfig` à chaque `Board` au démarrage.

**Tech Stack:** Godot 4.6.3, GDScript, tests headless via `SceneTree` (`Godot --headless --script tests/<file>.gd`).

---

## Mapping clavier retenu

- **Joueur 1 (gauche du clavier):**
  - Déplacement curseur : `W` `A` `S` `D`
  - Swap : `Espace` (`KEY_SPACE`)
  - Montée rapide (maintien) : `Shift gauche` (`KEY_SHIFT`)
- **Joueur 2 (droite du clavier, sans pavé numérique):**
  - Déplacement curseur : Flèches `↑` `↓` `←` `→`
  - Swap : `Entrée` (`KEY_ENTER`)
  - Montée rapide (maintien) : `Ctrl droit` (`KEY_CTRL`)

> Note technique : Godot ne permet pas de distinguer Shift gauche/droit ni Ctrl gauche/droit via `Input.is_key_pressed()` (un seul code `KEY_SHIFT` / `KEY_CTRL` pour les deux côtés). Pour éviter qu'une touche modificatrice pressée par un joueur déclenche aussi la montée rapide de l'autre, le joueur 1 utilise `KEY_SHIFT` et le joueur 2 utilise `KEY_CTRL` (deux codes différents, donc pas de collision entre les deux joueurs). Si un joueur appuie occasionnellement sur l'autre touche modificatrice par erreur, l'effet est mineur (montée rapide temporaire) et pourra être affiné plus tard si besoin.

> Remapping des touches : pas de menu de remapping pour cette itération (les deux schémas sont fixes). À noter pour une itération future : permettre à chaque joueur de personnaliser ses touches depuis le menu.

---

## Conventions GDScript à respecter (tirées des tâches précédentes)

- Indentation par tabulations, `:=` pour l'inférence de type quand le type est sans ambiguïté.
- `min()`/`max()`/`clampi()` retournent `Variant` ou un type non garanti pour `:=` selon les arguments — utiliser une variable typée explicitement (`var x: int = min(a, b)`) si besoin.
- Si un `Dictionary` non typé renvoie une valeur `Variant` utilisée dans un contexte qui exige un type concret (ex: `Input.is_key_pressed(keycode: Key)`), extraire dans une variable typée explicitement avant l'appel, par exemple :
  ```gdscript
  var keycode: Key = keys[dir_name]
  return Input.is_key_pressed(keycode)
  ```
  (GDScript 4.6 accepte l'assignation d'un `Variant` connu-int vers une variable typée `Key` via `:` avec conversion implicite à l'exécution ; si le compilateur se plaint, utiliser `as Key`.)

---

## Task 1: Singleton `GameConfig` (autoload)

**Files:**
- Create: `scripts/game_config.gd`
- Modify: `project.godot` (ajouter une section `[autoload]`)
- Test: `tests/test_game_config.gd`

- [ ] **Step 1: Créer `scripts/game_config.gd`**

```gdscript
extends Node

const SOURCE_KEYBOARD := "keyboard"
const SOURCE_GAMEPAD := "gamepad"

var player1_source: String = SOURCE_KEYBOARD
var player1_device: int = 0
var player2_source: String = SOURCE_KEYBOARD
var player2_device: int = 0
```

- [ ] **Step 2: Enregistrer l'autoload dans `project.godot`**

Ajouter une nouvelle section à la fin de `project.godot` :

```
[autoload]

GameConfig="*res://scripts/game_config.gd"
```

(Le `*` indique que le node est ajouté à l'arbre de scène ; c'est la syntaxe standard des autoloads Godot 4.)

- [ ] **Step 3: Écrire `tests/test_game_config.gd`**

```gdscript
extends SceneTree

func _initialize() -> void:
	# GameConfig est un autoload : il doit être accessible comme un singleton global.
	assert(GameConfig.player1_source == GameConfig.SOURCE_KEYBOARD)
	assert(GameConfig.player1_device == 0)
	assert(GameConfig.player2_source == GameConfig.SOURCE_KEYBOARD)
	assert(GameConfig.player2_device == 0)

	GameConfig.player1_source = GameConfig.SOURCE_GAMEPAD
	GameConfig.player1_device = 1
	assert(GameConfig.player1_source == GameConfig.SOURCE_GAMEPAD)
	assert(GameConfig.player1_device == 1)

	print("ALL TESTS PASSED")
	quit()
```

- [ ] **Step 4: Lancer le test**

```bash
pkill -f "Godot.app/Contents/MacOS/Godot" 2>/dev/null; sleep 1; cd "/Users/floriojulien/Code/Swap & Clash" && (/Users/floriojulien/Downloads/Godot.app/Contents/MacOS/Godot --headless --script tests/test_game_config.gd > /tmp/test_out.log 2>&1 &) ; sleep 8; pkill -f "Godot.app/Contents/MacOS/Godot"; sleep 1; cat /tmp/test_out.log
```

Attendu : `ALL TESTS PASSED`, pas de `SCRIPT ERROR`/`Invalid`.

> Si l'autoload `GameConfig` n'est pas reconnu en mode `--script` (erreur "Identifier not found"), c'est probablement parce que `--headless --import` doit être relancé une fois après modification de `project.godot` pour que Godot régénère sa configuration interne. Relancer :
> ```bash
> pkill -f "Godot.app/Contents/MacOS/Godot" 2>/dev/null; sleep 1; cd "/Users/floriojulien/Code/Swap & Clash" && (/Users/floriojulien/Downloads/Godot.app/Contents/MacOS/Godot --headless --import > /tmp/import.log 2>&1 &) ; sleep 8; pkill -f "Godot.app/Contents/MacOS/Godot"; sleep 1; cat /tmp/import.log
> ```
> puis relancer le test. Si le problème persiste, documenter le blocage précisément (DONE_WITH_CONCERNS) plutôt que de contourner avec un `preload` direct du script — l'autoload est nécessaire pour `SetupMenu`/`Match` (Tasks 3-4).

- [ ] **Step 5: Commit**

```bash
git add scripts/game_config.gd project.godot tests/test_game_config.gd
git commit -m "Add GameConfig autoload to store per-player input source"
```

---

## Task 2: Entrée clavier dans `Board`

**Files:**
- Modify: `scripts/board.gd`
- Test: `tests/test_keyboard_input.gd`

### Contexte

`scripts/board.gd` gère actuellement uniquement l'entrée manette via `@export var input_device: int` (voir `_process`, `_handle_cursor_movement`, `_is_direction_pressed`, lignes ~29-123). Il faut ajouter un mode clavier sélectionnable, sans casser le mode manette existant.

- [ ] **Step 1: Ajouter les constantes de mapping clavier et les exports**

Juste après la ligne `const JOY_AXIS_DEADZONE := 0.5` (ligne 31), ajouter :

```gdscript

@export_enum("gamepad", "keyboard") var input_source: String = "gamepad"
@export var keyboard_scheme: int = 1

const KEYBOARD_SCHEME_1 := {
	"left": KEY_A,
	"right": KEY_D,
	"up": KEY_W,
	"down": KEY_S,
	"swap": KEY_SPACE,
	"fast_rise": KEY_SHIFT,
}

const KEYBOARD_SCHEME_2 := {
	"left": KEY_LEFT,
	"right": KEY_RIGHT,
	"up": KEY_UP,
	"down": KEY_DOWN,
	"swap": KEY_ENTER,
	"fast_rise": KEY_CTRL,
}

func _keyboard_keys() -> Dictionary:
	return KEYBOARD_SCHEME_2 if keyboard_scheme == 2 else KEYBOARD_SCHEME_1
```

- [ ] **Step 2: Adapter `_process` pour lire swap / montée rapide selon `input_source`**

Remplacer (dans `_process`, lignes ~71-77) :

```gdscript
	var swap_pressed := Input.is_joy_button_pressed(input_device, JOY_BUTTON_A)
	if swap_pressed and not _swap_was_pressed and not is_resolving:
		_try_swap()
	_swap_was_pressed = swap_pressed

	if not is_resolving:
		var rise_speed := RISE_SPEED_FAST if Input.is_joy_button_pressed(input_device, JOY_BUTTON_B) else RISE_SPEED_NORMAL
```

par :

```gdscript
	var swap_pressed := _is_swap_pressed()
	if swap_pressed and not _swap_was_pressed and not is_resolving:
		_try_swap()
	_swap_was_pressed = swap_pressed

	if not is_resolving:
		var rise_speed := RISE_SPEED_FAST if _is_fast_rise_pressed() else RISE_SPEED_NORMAL
```

- [ ] **Step 3: Ajouter les helpers `_is_swap_pressed` et `_is_fast_rise_pressed`**

Ajouter ces deux fonctions juste avant `_is_direction_pressed` (ligne ~113) :

```gdscript
func _is_swap_pressed() -> bool:
	if input_source == "keyboard":
		var keycode: Key = _keyboard_keys()["swap"]
		return Input.is_key_pressed(keycode)
	return Input.is_joy_button_pressed(input_device, JOY_BUTTON_A)

func _is_fast_rise_pressed() -> bool:
	if input_source == "keyboard":
		var keycode: Key = _keyboard_keys()["fast_rise"]
		return Input.is_key_pressed(keycode)
	return Input.is_joy_button_pressed(input_device, JOY_BUTTON_B)
```

- [ ] **Step 4: Adapter `_is_direction_pressed` pour le mode clavier**

Remplacer le début de `_is_direction_pressed` (lignes ~113-123) :

```gdscript
func _is_direction_pressed(dir_name: String) -> bool:
	match dir_name:
		"left":
			return Input.is_joy_button_pressed(input_device, JOY_BUTTON_DPAD_LEFT) or Input.get_joy_axis(input_device, JOY_AXIS_LEFT_X) < -JOY_AXIS_DEADZONE
		"right":
			return Input.is_joy_button_pressed(input_device, JOY_BUTTON_DPAD_RIGHT) or Input.get_joy_axis(input_device, JOY_AXIS_LEFT_X) > JOY_AXIS_DEADZONE
		"up":
			return Input.is_joy_button_pressed(input_device, JOY_BUTTON_DPAD_UP) or Input.get_joy_axis(input_device, JOY_AXIS_LEFT_Y) < -JOY_AXIS_DEADZONE
		"down":
			return Input.is_joy_button_pressed(input_device, JOY_BUTTON_DPAD_DOWN) or Input.get_joy_axis(input_device, JOY_AXIS_LEFT_Y) > JOY_AXIS_DEADZONE
	return false
```

par :

```gdscript
func _is_direction_pressed(dir_name: String) -> bool:
	if input_source == "keyboard":
		var keycode: Key = _keyboard_keys()[dir_name]
		return Input.is_key_pressed(keycode)
	match dir_name:
		"left":
			return Input.is_joy_button_pressed(input_device, JOY_BUTTON_DPAD_LEFT) or Input.get_joy_axis(input_device, JOY_AXIS_LEFT_X) < -JOY_AXIS_DEADZONE
		"right":
			return Input.is_joy_button_pressed(input_device, JOY_BUTTON_DPAD_RIGHT) or Input.get_joy_axis(input_device, JOY_AXIS_LEFT_X) > JOY_AXIS_DEADZONE
		"up":
			return Input.is_joy_button_pressed(input_device, JOY_BUTTON_DPAD_UP) or Input.get_joy_axis(input_device, JOY_AXIS_LEFT_Y) < -JOY_AXIS_DEADZONE
		"down":
			return Input.is_joy_button_pressed(input_device, JOY_BUTTON_DPAD_DOWN) or Input.get_joy_axis(input_device, JOY_AXIS_LEFT_Y) > JOY_AXIS_DEADZONE
	return false
```

- [ ] **Step 5: Écrire `tests/test_keyboard_input.gd`**

```gdscript
extends SceneTree

const BoardScene := preload("res://scenes/Board.tscn")

var _board1: Variant = null
var _board2: Variant = null
var _phase := 0
var _frame := 0

func _initialize() -> void:
	_board1 = BoardScene.instantiate()
	_board1.input_source = "keyboard"
	_board1.keyboard_scheme = 1
	get_root().add_child(_board1)

	_board2 = BoardScene.instantiate()
	_board2.input_source = "keyboard"
	_board2.keyboard_scheme = 2
	get_root().add_child(_board2)

func _process(_delta: float) -> bool:
	var b1: Variant = _board1
	var b2: Variant = _board2

	if _phase == 0:
		var start_x1: int = b1.cursor_pos.x
		var start_x2: int = b2.cursor_pos.x

		# Player 1: D moves cursor right.
		var p1_right := InputEventKey.new()
		p1_right.physical_keycode = KEY_D
		p1_right.pressed = true
		Input.parse_input_event(p1_right)

		# Player 2: Left arrow moves cursor left.
		var p2_left := InputEventKey.new()
		p2_left.physical_keycode = KEY_LEFT
		p2_left.pressed = true
		Input.parse_input_event(p2_left)

		_phase = 1
		_frame = 0
		return false

	if _phase == 1:
		_frame += 1
		if _frame < 5:
			return false

		assert(b1.cursor_pos.x == clampi(b1.GRID_WIDTH / 2 - 1 + 1, 0, b1.GRID_WIDTH - 2))
		assert(b2.cursor_pos.x == clampi(b2.GRID_WIDTH / 2 - 1 - 1, 0, b2.GRID_WIDTH - 2))

		var p1_right_release := InputEventKey.new()
		p1_right_release.physical_keycode = KEY_D
		p1_right_release.pressed = false
		Input.parse_input_event(p1_right_release)

		var p2_left_release := InputEventKey.new()
		p2_left_release.physical_keycode = KEY_LEFT
		p2_left_release.pressed = false
		Input.parse_input_event(p2_left_release)

		# Player 2 presses Right arrow: should not move player 1's cursor (different scheme).
		var p2_right := InputEventKey.new()
		p2_right.physical_keycode = KEY_RIGHT
		p2_right.pressed = true
		Input.parse_input_event(p2_right)

		_phase = 2
		_frame = 0
		return false

	if _phase == 2:
		_frame += 1
		if _frame < 5:
			return false

		var b1_x_after: int = b1.cursor_pos.x
		assert(b2.cursor_pos.x == b2.GRID_WIDTH / 2 - 1)

		var p2_right_release := InputEventKey.new()
		p2_right_release.physical_keycode = KEY_RIGHT
		p2_right_release.pressed = false
		Input.parse_input_event(p2_right_release)

		# Player 1 fast-rise key (Shift) should not affect player 2.
		var shift_press := InputEventKey.new()
		shift_press.physical_keycode = KEY_SHIFT
		shift_press.pressed = true
		Input.parse_input_event(shift_press)

		_phase = 3
		_frame = 0
		_extra_data = b1_x_after
		return false

	_frame += 1
	if _frame < 2:
		return false

	assert(b1._is_fast_rise_pressed() == true)
	assert(b2._is_fast_rise_pressed() == false)

	var shift_release := InputEventKey.new()
	shift_release.physical_keycode = KEY_SHIFT
	shift_release.pressed = false
	Input.parse_input_event(shift_release)

	print("ALL TESTS PASSED")
	quit()
	return true

var _extra_data: int = 0
```

> Note pour l'implémenteur : `InputEventKey.physical_keycode` doit être utilisé (pas `keycode`) car `Input.is_key_pressed()` lit l'état du clavier physique en mode headless de la même manière que pour les manettes dans `test_gamepad_input.gd`. Si `Input.is_key_pressed(KEY_X)` ne reflète pas l'état après `parse_input_event` avec `physical_keycode`, essayer de renseigner à la fois `keycode` et `physical_keycode` sur l'événement, ou utiliser `Input.is_physical_key_pressed()` côté `board.gd` à la place de `Input.is_key_pressed()` (et adapter le test en conséquence). Documenter le choix retenu.

- [ ] **Step 6: Lancer le nouveau test, puis les tests de régression manette**

```bash
pkill -f "Godot.app/Contents/MacOS/Godot" 2>/dev/null; sleep 1; cd "/Users/floriojulien/Code/Swap & Clash" && (/Users/floriojulien/Downloads/Godot.app/Contents/MacOS/Godot --headless --script tests/test_keyboard_input.gd > /tmp/test_out.log 2>&1 &) ; sleep 8; pkill -f "Godot.app/Contents/MacOS/Godot"; sleep 1; cat /tmp/test_out.log
```

```bash
pkill -f "Godot.app/Contents/MacOS/Godot" 2>/dev/null; sleep 1; cd "/Users/floriojulien/Code/Swap & Clash" && (/Users/floriojulien/Downloads/Godot.app/Contents/MacOS/Godot --headless --script tests/test_gamepad_input.gd > /tmp/test_out.log 2>&1 &) ; sleep 8; pkill -f "Godot.app/Contents/MacOS/Godot"; sleep 1; cat /tmp/test_out.log
```

Les deux doivent finir par `ALL TESTS PASSED`, sans `SCRIPT ERROR`/`Invalid`. (Note : `Board.tscn` a `input_source` par défaut = `"gamepad"`, donc `test_gamepad_input.gd` n'est pas affecté par ce changement.)

- [ ] **Step 7: Commit**

```bash
git add scripts/board.gd tests/test_keyboard_input.gd
git commit -m "Add keyboard input support to Board (2 fixed key schemes)"
```

---

## Task 3: Scène `SetupMenu`

**Files:**
- Create: `scripts/setup_menu.gd`
- Create: `scenes/SetupMenu.tscn`
- Test: `tests/test_setup_menu.gd`

### Contexte

Cette scène devient la nouvelle scène principale (câblée dans Task 5). Elle affiche pour chaque joueur un `OptionButton` avec "Clavier" en première option, suivi d'une entrée "Manette N" par manette détectée (`Input.get_connected_joypads()`). Le bouton "Démarrer" écrit le choix dans `GameConfig` puis charge `Match.tscn`.

- [ ] **Step 1: Créer `scripts/setup_menu.gd`**

```gdscript
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
	var index := option.selected
	var source: String = GameConfig.SOURCE_KEYBOARD if index == 0 else GameConfig.SOURCE_GAMEPAD
	var device := 0
	if index > 0:
		var joypads := Input.get_connected_joypads()
		device = joypads[index - 1]
	if is_player1:
		GameConfig.player1_source = source
		GameConfig.player1_device = device
	else:
		GameConfig.player2_source = source
		GameConfig.player2_device = device
```

- [ ] **Step 2: Créer `scenes/SetupMenu.tscn`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/setup_menu.gd" id="1"]

[node name="SetupMenu" type="Node2D"]
script = ExtResource("1")

[node name="TitleLabel" type="Label" parent="."]
offset_left = 260.0
offset_top = 120.0
offset_right = 660.0
offset_bottom = 170.0
theme_override_font_sizes/font_size = 36
horizontal_alignment = 1
text = "Swap & Clash"

[node name="Player1Label" type="Label" parent="."]
offset_left = 260.0
offset_top = 280.0
offset_right = 460.0
offset_bottom = 320.0
theme_override_font_sizes/font_size = 22
text = "Joueur 1 :"

[node name="Player1Option" type="OptionButton" parent="."]
offset_left = 460.0
offset_top = 280.0
offset_right = 660.0
offset_bottom = 320.0

[node name="Player2Label" type="Label" parent="."]
offset_left = 260.0
offset_top = 360.0
offset_right = 460.0
offset_bottom = 400.0
theme_override_font_sizes/font_size = 22
text = "Joueur 2 :"

[node name="Player2Option" type="OptionButton" parent="."]
offset_left = 460.0
offset_top = 360.0
offset_right = 660.0
offset_bottom = 400.0

[node name="StartButton" type="Button" parent="."]
offset_left = 410.0
offset_top = 480.0
offset_right = 510.0
offset_bottom = 520.0
text = "Démarrer"
```

- [ ] **Step 3: Écrire `tests/test_setup_menu.gd`**

> Note : ce script `extends SceneTree` ne peut pas utiliser l'identifiant global `GameConfig` directement (limitation confirmée de Godot 4.6.3 : "Identifier not found: GameConfig" en mode `--headless --script` pour les scripts SceneTree, voir Task 1). Utiliser `get_root().get_node("GameConfig")` à la place. Les scripts `Node`/`Node2D` (comme `setup_menu.gd` lui-même) n'ont pas ce problème et peuvent utiliser `GameConfig` directement.

```gdscript
extends SceneTree

const SetupMenuScene := preload("res://scenes/SetupMenu.tscn")

var _menu: Variant = null

func _initialize() -> void:
	_menu = SetupMenuScene.instantiate()
	get_root().add_child(_menu)

func _process(_delta: float) -> bool:
	var menu: Variant = _menu
	var config: Variant = get_root().get_node("GameConfig")

	# Headless: no joypads connected -> only "Clavier" for each player.
	assert(menu.player1_option.item_count == 1)
	assert(menu.player1_option.get_item_text(0) == "Clavier")
	assert(menu.player1_option.selected == 0)
	assert(menu.player2_option.item_count == 1)
	assert(menu.player2_option.get_item_text(0) == "Clavier")
	assert(menu.player2_option.selected == 0)

	# Starting with default selection (Clavier/Clavier) writes to GameConfig.
	menu._on_start_pressed()
	assert(config.player1_source == config.SOURCE_KEYBOARD)
	assert(config.player2_source == config.SOURCE_KEYBOARD)

	print("ALL TESTS PASSED")
	quit()
	return true
```

- [ ] **Step 4: Lancer le test**

```bash
pkill -f "Godot.app/Contents/MacOS/Godot" 2>/dev/null; sleep 1; cd "/Users/floriojulien/Code/Swap & Clash" && (/Users/floriojulien/Downloads/Godot.app/Contents/MacOS/Godot --headless --script tests/test_setup_menu.gd > /tmp/test_out.log 2>&1 &) ; sleep 8; pkill -f "Godot.app/Contents/MacOS/Godot"; sleep 1; cat /tmp/test_out.log
```

Attendu : `ALL TESTS PASSED`, pas de `SCRIPT ERROR`/`Invalid`.

> Note : ce test instancie `SetupMenu.tscn` directement (pas via `change_scene_to_file`), donc `_on_start_pressed()` appelle `get_tree().change_scene_to_file("res://scenes/Match.tscn")` sur le `SceneTree` du test. Ce n'est pas un problème pour le test (il `quit()` juste après), mais si un `SCRIPT ERROR` apparaît à cause de ce changement de scène différé, déplacer l'assertion `GameConfig` AVANT l'appel à `_on_start_pressed`'s scene-change, ou refactorer `_on_start_pressed` pour séparer `_apply_selection` (testable) du `change_scene_to_file` (non testé ici). Documenter le choix.

- [ ] **Step 5: Commit**

```bash
git add scripts/setup_menu.gd scenes/SetupMenu.tscn tests/test_setup_menu.gd
git commit -m "Add SetupMenu scene for choosing keyboard/gamepad per player"
```

---

## Task 4: `Match` applique `GameConfig`, suppression de l'écran d'attente

**Files:**
- Modify: `scripts/match.gd`
- Modify: `scenes/Match.tscn`
- Modify: `tests/test_match.gd`

### Contexte

`scripts/match.gd` (voir contenu actuel ci-dessous) attend actuellement 2 manettes avant de démarrer (`_started`, `waiting_panel`). Comme le clavier est toujours disponible, la partie doit démarrer immédiatement, en appliquant la configuration de `GameConfig` à chaque `Board`.

Contenu actuel de `scripts/match.gd` :

```gdscript
extends Node2D

@onready var board1: Node2D = $Board1
@onready var board2: Node2D = $Board2
@onready var score_label1: Label = $ScoreLabel1
@onready var score_label2: Label = $ScoreLabel2
@onready var garbage_label1: Label = $GarbageLabel1
@onready var garbage_label2: Label = $GarbageLabel2
@onready var waiting_panel: ColorRect = $WaitingPanel
@onready var waiting_label: Label = $WaitingPanel/WaitingLabel
@onready var end_panel: ColorRect = $EndPanel
@onready var end_label: Label = $EndPanel/EndLabel
@onready var restart_button: Button = $EndPanel/RestartButton

var _started := false

func _ready() -> void:
	board1.input_device = 0
	board2.input_device = 1
	board1.set_process(false)
	board2.set_process(false)

	board1.score_changed.connect(func(s: int): score_label1.text = "Score: %d" % s)
	board2.score_changed.connect(func(s: int): score_label2.text = "Score: %d" % s)

	board1.garbage_sent.connect(board2.receive_garbage)
	board2.garbage_sent.connect(board1.receive_garbage)

	board1.game_over.connect(func(): _on_game_over(2))
	board2.game_over.connect(func(): _on_game_over(1))

	restart_button.pressed.connect(func(): get_tree().reload_current_scene())
	end_panel.visible = false

func _process(_delta: float) -> void:
	if not _started:
		var connected := Input.get_connected_joypads().size()
		var shown: int = min(connected, 2)
		waiting_label.text = "En attente de manettes (%d/2 connectées)" % shown
		if connected >= 2:
			_started = true
			waiting_panel.visible = false
			board1.set_process(true)
			board2.set_process(true)
		return

	garbage_label1.text = "Garbage entrant: %d" % board1.pending_garbage.size()
	garbage_label2.text = "Garbage entrant: %d" % board2.pending_garbage.size()

func _on_game_over(winner: int) -> void:
	board1.set_process(false)
	board2.set_process(false)
	end_label.text = "Joueur %d gagne !" % winner
	end_panel.visible = true
```

- [ ] **Step 1: Réécrire `scripts/match.gd`**

```gdscript
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
	board1.input_source = GameConfig.player1_source
	board1.input_device = GameConfig.player1_device
	board1.keyboard_scheme = 1

	board2.input_source = GameConfig.player2_source
	board2.input_device = GameConfig.player2_device
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
```

Notes :
- Les boards démarrent maintenant directement en mode `set_process(true)` (valeur par défaut de `Node`, donc rien à faire pour les activer).
- `keyboard_scheme` est toujours fixé à 1/2 indépendamment de `input_source` : si un joueur choisit le clavier, il utilise son schéma dédié ; si les deux choisissent le clavier, il n'y a aucun conflit (touches différentes).

- [ ] **Step 2: Retirer `WaitingPanel`/`WaitingLabel` de `scenes/Match.tscn`**

Dans `scenes/Match.tscn`, supprimer entièrement les deux blocs :

```
[node name="WaitingPanel" type="ColorRect" parent="."]
offset_right = 920.0
offset_bottom = 800.0
color = Color(0, 0, 0, 0.85)

[node name="WaitingLabel" type="Label" parent="WaitingPanel"]
offset_left = 200.0
offset_top = 380.0
offset_right = 720.0
offset_bottom = 420.0
theme_override_font_sizes/font_size = 28
horizontal_alignment = 1
text = "En attente de manettes (0/2 connectées)"
```

Le reste du fichier (`Board1`, `Board2`, labels de score/garbage, `EndPanel`) reste inchangé.

- [ ] **Step 3: Mettre à jour `tests/test_match.gd`**

> Note : ce script `extends SceneTree` ne peut pas utiliser l'identifiant global `GameConfig` directement (limitation confirmée de Godot 4.6.3, voir Task 1) — utiliser `get_root().get_node("GameConfig")`. `match.gd` lui-même (Node2D) peut utiliser `GameConfig` directement sans problème.

Remplacer le contenu actuel par :

```gdscript
extends SceneTree

const MatchScene := preload("res://scenes/Match.tscn")

var _match: Variant = null

func _initialize() -> void:
	var config: Variant = get_root().get_node("GameConfig")
	config.player1_source = config.SOURCE_KEYBOARD
	config.player1_device = 0
	config.player2_source = config.SOURCE_KEYBOARD
	config.player2_device = 0

	_match = MatchScene.instantiate()
	get_root().add_child(_match)

func _process(_delta: float) -> bool:
	var m: Variant = _match
	var config: Variant = get_root().get_node("GameConfig")

	# No waiting screen: both boards start processing immediately.
	assert(m.has_node("WaitingPanel") == false)
	assert(m.board1.is_processing() == true)
	assert(m.board2.is_processing() == true)

	# GameConfig is applied to each board.
	assert(m.board1.input_source == config.SOURCE_KEYBOARD)
	assert(m.board1.keyboard_scheme == 1)
	assert(m.board2.input_source == config.SOURCE_KEYBOARD)
	assert(m.board2.keyboard_scheme == 2)

	# garbage_sent on one board routes to receive_garbage on the other.
	m.board1.garbage_sent.emit(5)
	assert(m.board2.pending_garbage.size() == 1)
	assert(m.board2.pending_garbage[0].power == 5)

	m.board2.garbage_sent.emit(3)
	assert(m.board1.pending_garbage.size() == 1)
	assert(m.board1.pending_garbage[0].power == 3)

	# game_over on board1 means player 2 wins.
	m.board1.game_over.emit()
	assert(m.end_panel.visible == true)
	assert(m.end_label.text == "Joueur 2 gagne !")
	assert(m.board1.is_processing() == false)
	assert(m.board2.is_processing() == false)

	print("ALL TESTS PASSED")
	quit()
	return true
```

- [ ] **Step 4: Lancer les tests**

```bash
pkill -f "Godot.app/Contents/MacOS/Godot" 2>/dev/null; sleep 1; cd "/Users/floriojulien/Code/Swap & Clash" && (/Users/floriojulien/Downloads/Godot.app/Contents/MacOS/Godot --headless --script tests/test_match.gd > /tmp/test_out.log 2>&1 &) ; sleep 8; pkill -f "Godot.app/Contents/MacOS/Godot"; sleep 1; cat /tmp/test_out.log
```

Attendu : `ALL TESTS PASSED`, pas de `SCRIPT ERROR`/`Invalid`.

- [ ] **Step 5: Commit**

```bash
git add scripts/match.gd scenes/Match.tscn tests/test_match.gd
git commit -m "Apply GameConfig to boards and remove gamepad waiting screen"
```

---

## Task 5: Câbler `SetupMenu` comme scène principale, vérification finale

**Files:**
- Modify: `project.godot`

- [ ] **Step 1: Modifier `project.godot`**

Changer `run/main_scene` :

```
run/main_scene="res://scenes/Match.tscn"
```

en :

```
run/main_scene="res://scenes/SetupMenu.tscn"
```

(la section `[autoload]` ajoutée en Task 1 reste inchangée)

- [ ] **Step 2: Vérifier l'import**

```bash
pkill -f "Godot.app/Contents/MacOS/Godot" 2>/dev/null; sleep 1; cd "/Users/floriojulien/Code/Swap & Clash" && (/Users/floriojulien/Downloads/Godot.app/Contents/MacOS/Godot --headless --import > /tmp/import.log 2>&1 &) ; sleep 8; pkill -f "Godot.app/Contents/MacOS/Godot"; sleep 1; cat /tmp/import.log
```

Attendu : pas de `SCRIPT ERROR`/`Parse Error`.

- [ ] **Step 3: Lancer la suite de tests complète (régression)**

Lister tous les fichiers `tests/*.gd` et lancer chacun avec :

```bash
pkill -f "Godot.app/Contents/MacOS/Godot" 2>/dev/null; sleep 1; cd "/Users/floriojulien/Code/Swap & Clash" && (/Users/floriojulien/Downloads/Godot.app/Contents/MacOS/Godot --headless --script tests/<file>.gd > /tmp/test_out.log 2>&1 &) ; sleep 8; pkill -f "Godot.app/Contents/MacOS/Godot"; sleep 1; cat /tmp/test_out.log
```

Tous doivent finir par `ALL TESTS PASSED`, sans `SCRIPT ERROR`/`Invalid`.

- [ ] **Step 4: Commit**

```bash
git add project.godot
git commit -m "Set SetupMenu as the main scene"
```

---

## Hors scope (cette itération)

- Menu de remapping des touches (noté pour une itération future).
- Sélection d'un device manette spécifique au-delà de l'ordre de détection (`Input.get_connected_joypads()`).
- Bouton "Retour au menu" depuis `Match.tscn` (le bouton "Rejouer" recharge `Match.tscn` directement, en conservant la config `GameConfig` actuelle).
- `Game.tscn` / `game.gd` (scène solo de l'étape 1) : non modifiés, restent accessibles uniquement à la manette device 0 comme avant.
