class_name Roster
extends Control

## The player tapped `adventurer`, a key of Dispatch.ADVENTURERS, to see them.
signal adventurer_pressed(adventurer: String)

var _statuses: Dictionary[String, Label] = {}
var _details: Dictionary[String, Label] = {}
var _healths: Dictionary[String, HBoxContainer] = {}

@onready var _list: VBoxContainer = $Scroll/Box/List


func _ready() -> void:
	for adventurer: String in Dispatch.ADVENTURERS:
		var name_line := HBoxContainer.new()
		name_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_label := _label(Dispatch.ADVENTURERS[adventurer]["name"], &"RowTitle")
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_line.add_child(name_label)
		var status := _label("", &"Secondary")
		status.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_line.add_child(status)
		_statuses[adventurer] = status
		var details := _label("", &"Secondary")
		_details[adventurer] = details
		var words := VBoxContainer.new()
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		words.add_child(name_line)
		words.add_child(details)
		_healths[adventurer] = Adventurer.health_row()
		words.add_child(_healths[adventurer])
		var line := HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_theme_constant_override("separation", 32)
		line.add_child(QuestBoard.token(adventurer))
		line.add_child(words)
		var row := Button.new()
		row.custom_minimum_size = Vector2(0, 220)
		row.add_child(line)
		line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		line.offset_left = 36
		line.offset_right = -36
		row.pressed.connect(adventurer_pressed.emit.bind(adventurer))
		_list.add_child(row)


func show_dispatch(dispatch: Dispatch, now: int) -> void:
	for adventurer: String in _statuses:
		var info: Dictionary = Dispatch.ADVENTURERS[adventurer]
		_details[adventurer].text = "%s · rank %s · level %d" % [info["class"], info["rank"], dispatch.adventurers.levels[adventurer]]
		var status := _statuses[adventurer]
		status.text = dispatch.status(adventurer, now)
		status.theme_type_variation = status_look(dispatch, adventurer, now)
		Adventurer.show_health(_healths[adventurer], adventurer, dispatch, now)


## The adventurer `step` places after `adventurer` in roster order, wrapping around at the ends.
static func adventurer_after(adventurer: String, step: int) -> String:
	var order := Dispatch.ADVENTURERS.keys()
	return order[posmod(order.find(adventurer) + step, order.size())]


## How `adventurer`'s status reads at `now`: hurt, free to go, or busy.
static func status_look(dispatch: Dispatch, adventurer: String, now: int) -> StringName:
	if dispatch.injury_left(adventurer, now) > 0:
		return &"Alert"
	if dispatch.can_go(adventurer, now):
		return &"Ok"
	return &"Secondary"


func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.theme_type_variation = variation
	return label
