class_name MenuNav
extends Node

## Drop-in gamepad/keyboard navigation for a menu.
##
## Add this as a child of a menu root. It gives the first button keyboard/gamepad
## focus, animates the focused button (grow + brighten), mirrors that highlight on
## mouse hover, and maps the cancel action (gamepad B) to a sibling "BackButton".

const FOCUS_SCALE := Vector2(1.1, 1.1)
const FOCUS_MODULATE := Color(1.25, 1.25, 1.25)
const ANIM_TIME := 0.12

## Optional explicit starting focus. Defaults to the first focusable button.
@export var default_focus: NodePath

## When true, only wire up/down focus neighbors (leaves left/right free, e.g. for
## a value stepper that reads ui_left/ui_right itself).
@export var vertical_only: bool = false

var _buttons: Array[Button] = []
var _back_button: Button = null
var _tweens: Dictionary = {}

func _ready() -> void:
	_collect_buttons(get_parent())

	for button in _buttons:
		if button.name == "BackButton":
			_back_button = button
		button.focus_entered.connect(_on_focus_entered.bind(button))
		button.focus_exited.connect(_on_focus_exited.bind(button))
		button.mouse_entered.connect(button.grab_focus)

	_wire_focus_neighbors()
	refresh()

## Godot's automatic focus-neighbor search needs a Control ancestor to search
## within; these menus use a Node2D root, so it finds nothing. Wire neighbors
## explicitly along the (tree-ordered) button list, wrapping around. Every
## direction maps to prev/next so a stick push in any axis still moves the
## selection. find_valid_focus_neighbor skips disabled buttons in the chain.
func _wire_focus_neighbors() -> void:
	var count := _buttons.size()
	if count < 2:
		return
	for i in count:
		var prev := _buttons[(i - 1 + count) % count].get_path()
		var next := _buttons[(i + 1) % count].get_path()
		var button := _buttons[i]
		button.focus_neighbor_top = prev
		button.focus_neighbor_bottom = next
		if not vertical_only:
			button.focus_neighbor_left = prev
			button.focus_neighbor_right = next

## Gives focus to the first visible, enabled button. Safe to call repeatedly
## (e.g. when a popup re-shows with a different set of visible buttons).
func refresh() -> void:
	if default_focus and not default_focus.is_empty():
		var node := get_node_or_null(default_focus)
		if node is Button and _is_focusable(node):
			node.grab_focus()
			return
	for button in _buttons:
		if _is_focusable(button):
			button.grab_focus()
			return

func _collect_buttons(node: Node) -> void:
	for child in node.get_children():
		# Skip non-focusable buttons (e.g. mouse-only stepper arrows).
		if child is Button and child.focus_mode != Control.FOCUS_NONE:
			_buttons.append(child)
		_collect_buttons(child)

func _is_focusable(button: Button) -> bool:
	return button.visible and not button.disabled and button.is_visible_in_tree()

func _on_focus_entered(button: Button) -> void:
	button.pivot_offset = button.size / 2.0
	_tween_to(button, FOCUS_SCALE, FOCUS_MODULATE, true)

func _on_focus_exited(button: Button) -> void:
	_tween_to(button, Vector2.ONE, Color.WHITE, false)

func _tween_to(button: Button, scale: Vector2, modulate: Color, bounce: bool) -> void:
	var previous: Variant = _tweens.get(button)
	if previous is Tween and previous.is_valid():
		previous.kill()
	var tween := button.create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK if bounce else Tween.TRANS_QUAD)
	tween.tween_property(button, "scale", scale, ANIM_TIME)
	tween.tween_property(button, "modulate", modulate, ANIM_TIME)
	_tweens[button] = tween

func _unhandled_input(event: InputEvent) -> void:
	if _back_button == null:
		return
	if event.is_action_pressed("ui_cancel"):
		_back_button.pressed.emit()
		get_viewport().set_input_as_handled()
