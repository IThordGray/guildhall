class_name Touch
extends Node
## Makes touch feel native on every screen: a drag anywhere on a scrolling screen scrolls it, and a
## press is a tap only when it is released without having moved further than TAP_SLOP_PX.

## How far a press may move and still be a tap, in pixels at the project's base size. Past it the
## press is a drag: it scrolls, and the control it started on neither fires, toggles nor stays lit.
const TAP_SLOP_PX: int = 10

## Where the held press started, in viewport pixels.
var _press_at: Vector2 = Vector2.ZERO
## The button the held press started on, until the press turns into a drag.
var _pressed: BaseButton = null


# Only mouse events are read: touch arrives as the mouse events Godot emulates from it, the same
# ones buttons press on. Nothing is marked handled, so the controls still get every event, after
# this has seen it.
func _input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT:
		_pressed = null
		if click.pressed:
			_press_at = click.position
			_pressed = _start_press(get_viewport().gui_get_hovered_control())
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _pressed != null and motion.position.distance_to(_press_at) > TAP_SLOP_PX:
		# What a ScrollContainer sends its content when a drag starts scrolling it: a button drops
		# the press it holds, so the release does nothing.
		_pressed.notification(Control.NOTIFICATION_SCROLL_BEGIN)
		_pressed = null


# A ScrollContainer follows a finger only with the pointer events that reach it, and a control that
# stops them, as buttons, panels and plain controls do by default, keeps them from it. So the
# controls between `hit` and the scroll it is in pass them on instead, and the scroll starts moving
# only past the tap's slop. Returns the button `hit` presses, if any.
func _start_press(hit: Control) -> BaseButton:
	# A scroll bar keeps its drag to itself.
	if hit is ScrollBar:
		return null
	var button: BaseButton = null
	var below: Array[Control] = []
	var node: Node = hit
	while node is Control:
		if button == null and node is BaseButton:
			button = node
		var scroll := node as ScrollContainer
		if scroll != null:
			scroll.scroll_deadzone = TAP_SLOP_PX
			for control: Control in below:
				if control.mouse_filter == Control.MOUSE_FILTER_STOP:
					control.mouse_filter = Control.MOUSE_FILTER_PASS
			break
		below.append(node)
		node = node.get_parent()
	return button
