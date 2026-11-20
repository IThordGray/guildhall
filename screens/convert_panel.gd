class_name ConvertPanel
extends PanelContainer

## The player chose to convert the room the panel is open for into `type`, a key of Hall.ROOM_TYPES.
signal convert_pressed(type: String)

## The panel keeps at least this far from the window's top and bottom; choices that don't fit scroll.
const WINDOW_MARGIN_PX: float = 48.0

var _choices: Dictionary[String, Button] = {}
var _reasons: Dictionary[String, Label] = {}
var _scroll: ScrollContainer

@onready var _list: VBoxContainer = $Box/List


func _ready() -> void:
	for type: String in Hall.ROOM_TYPES:
		var info: Dictionary = Hall.ROOM_TYPES[type]
		var choice := Button.new()
		choice.custom_minimum_size = Vector2(0, 170)
		choice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		choice.text = "%s — %s\n%d gold · %s" % [info["name"], info["blurb"], info["gold"], Duration.label(info["seconds"])]
		choice.pressed.connect(convert_pressed.emit.bind(type))
		var reason := Label.new()
		reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reason.theme_type_variation = &"Alert"
		_choices[type] = choice
		_reasons[type] = reason
		_list.add_child(choice)
		_list.add_child(reason)
	# The choices sit in a scroll between the title and Cancel, which stay in view.
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	$Box.add_child(_scroll)
	$Box.move_child(_scroll, _list.get_index())
	_list.reparent(_scroll, false)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	$Box/Cancel.pressed.connect(hide)


## Shows which choices `slot` can be converted into at `now`, and why not for the others.
func show_hall(hall: Hall, slot: String, gold: Gold, now: int) -> void:
	for type: String in _choices:
		var reason := hall.convert_refusal(slot, type, gold, now)
		_choices[type].disabled = not reason.is_empty()
		_reasons[type].text = reason
		_reasons[type].visible = not reason.is_empty()
	_fit()


# Gives the choices the height they need, or what the window leaves them once the rest of the
# panel is in, so the panel never runs off screen.
func _fit() -> void:
	var rest := get_combined_minimum_size().y - _scroll.custom_minimum_size.y
	var room := get_viewport_rect().size.y - 2 * WINDOW_MARGIN_PX - rest
	_scroll.custom_minimum_size.y = minf(_list.get_combined_minimum_size().y, room)
