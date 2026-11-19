class_name ConvertPanel
extends PanelContainer

## The player chose to convert the room the panel is open for into `type`, a key of Hall.ROOM_TYPES.
signal convert_pressed(type: String)

var _choices: Dictionary[String, Button] = {}
var _reasons: Dictionary[String, Label] = {}

@onready var _list: VBoxContainer = $Box/List


func _ready() -> void:
	for type: String in Hall.ROOM_TYPES:
		var info: Dictionary = Hall.ROOM_TYPES[type]
		var choice := Button.new()
		choice.custom_minimum_size = Vector2(0, 170)
		choice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		choice.add_theme_font_size_override("font_size", 44)
		choice.text = "%s — %s\n%d gold · %s" % [info["name"], info["blurb"], info["gold"], Duration.label(info["seconds"])]
		choice.pressed.connect(convert_pressed.emit.bind(type))
		var reason := Label.new()
		reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reason.add_theme_font_size_override("font_size", 40)
		reason.add_theme_color_override("font_color", Color(1, 0.62, 0.45))
		_choices[type] = choice
		_reasons[type] = reason
		_list.add_child(choice)
		_list.add_child(reason)
	$Box/Cancel.pressed.connect(hide)


## Shows which choices `slot` can be converted into at `now`, and why not for the others.
func show_hall(hall: Hall, slot: String, gold: Gold, now: int) -> void:
	for type: String in _choices:
		var reason := hall.convert_refusal(slot, type, gold, now)
		_choices[type].disabled = not reason.is_empty()
		_reasons[type].text = reason
		_reasons[type].visible = not reason.is_empty()
