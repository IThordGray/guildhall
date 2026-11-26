class_name ConvertPanel
extends Control

## The player chose to convert the room the screen is open for into `type`, a key of Hall.ROOM_TYPES.
signal convert_pressed(type: String)
## The player is done choosing without converting.
signal back_pressed

var _choices: Dictionary[String, Button] = {}
var _reasons: Dictionary[String, Label] = {}

@onready var _list: VBoxContainer = $Box/Scroll/List


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
	($Box/Back as Button).pressed.connect(back_pressed.emit)


## Shows which types `slot` can be converted into at `now`, and why not for the others, for a guild
## whose goals have unlocked `unlocked` (Goals.unlocked); a type not unlocked yet isn't shown.
func show_hall(hall: Hall, slot: String, gold: Gold, now: int, unlocked: PackedStringArray = PackedStringArray()) -> void:
	for type: String in _choices:
		var reason := hall.convert_refusal(slot, type, gold, now, unlocked)
		var shown := Hall.is_unlocked(type, unlocked)
		_choices[type].visible = shown
		_choices[type].disabled = not reason.is_empty()
		_reasons[type].text = reason
		_reasons[type].visible = shown and not reason.is_empty()
