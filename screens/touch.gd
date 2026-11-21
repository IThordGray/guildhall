class_name Touch
extends Node
## Makes touch feel native on every screen: a drag anywhere on a scrolling screen scrolls it, and a
## press is a tap only when it is released without having moved further than the tap's slop.

## How far a press may move and still be a tap, as a share of the screen's short side: 10 dp on a
## phone about 400 dp across, the touch slop of Android (8 dp) and iOS (about 10 pt). The short side
## stands in for the screen's physical size, which the web reports only in nominal CSS inches, so
## the slop is the same finger travel on any phone, in either orientation. Past it the press is a
## drag: it scrolls, and the control it started on neither fires, toggles nor stays lit.
const TAP_SLOP_SHORT_SIDE: float = 10.0 / 400.0

## Where the held press started, in viewport pixels.
var _press_at: Vector2 = Vector2.ZERO
## The tap's slop for the held press, in viewport pixels.
var _slop_px: float = 0.0
## The button the held press started on, until the press turns into a drag.
var _pressed: BaseButton = null
## Whether the held press landed on a scroll still gliding from a fling, which it only stops.
var _stopped_glide: bool = false


## The tap's slop in pixels of a viewport whose visible size is `visible`.
static func tap_slop_px(visible: Vector2) -> float:
	return minf(visible.x, visible.y) * TAP_SLOP_SHORT_SIDE


## `card` with a button over the whole of it, so a tap anywhere on it presses `action`, its one
## action: see `cover`.
static func whole_card(card: Control, action: BaseButton) -> MarginContainer:
	# A MarginContainer stacks its children, so the cover is the card's size.
	var stack := MarginContainer.new()
	stack.add_child(card)
	stack.add_child(cover([action]))
	return stack


## A see-through button to lay over a card whose one action at a time is among `actions`: a tap on
## it presses whichever of them shows, which stays the visible cue. While that one is disabled, it
## keeps its disabled look and reason, and the tap does nothing.
static func cover(actions: Array[BaseButton]) -> Button:
	var button := Button.new()
	button.flat = true
	button.pressed.connect(func() -> void:
		for action: BaseButton in actions:
			if action.is_visible_in_tree():
				if not action.disabled:
					action.pressed.emit()
				return)
	return button


# Only mouse events are read: touch arrives as the mouse events Godot emulates from it, the same
# ones buttons press on. Nothing is marked handled, so the controls still get every event, after
# this has seen it.
func _input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT:
		# A press that stopped a glide only stops it: its release presses nothing.
		if not click.pressed and _pressed != null and _stopped_glide:
			_pressed.notification(Control.NOTIFICATION_SCROLL_BEGIN)
		_pressed = null
		_stopped_glide = false
		if click.pressed:
			_press_at = click.position
			_slop_px = tap_slop_px(get_viewport().get_visible_rect().size)
			_pressed = _start_press(get_viewport().gui_get_hovered_control())
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _pressed != null and motion.position.distance_to(_press_at) > _slop_px:
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
			scroll.scroll_deadzone = roundi(_slop_px)
			# A scroll processes only while a finger drags it or it glides after a fling; the
			# finger is up before a press, so it glides. The press stops it, as the scroll sees it.
			_stopped_glide = scroll.is_processing_internal()
			for control: Control in below:
				if control.mouse_filter == Control.MOUSE_FILTER_STOP:
					control.mouse_filter = Control.MOUSE_FILTER_PASS
			break
		below.append(node)
		node = node.get_parent()
	return button
