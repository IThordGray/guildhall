class_name Roster
extends Control

var _statuses: Dictionary[String, Label] = {}

@onready var _list: VBoxContainer = $Box/List


func _ready() -> void:
	for adventurer: String in Dispatch.ADVENTURERS:
		var info: Dictionary = Dispatch.ADVENTURERS[adventurer]
		var words := VBoxContainer.new()
		words.add_child(_label(info["name"], &"Heading"))
		words.add_child(_label("%s · rank %s · power %d" % [info["class"], info["rank"], info["power"]], &"Secondary"))
		var status := _label("", &"Secondary")
		words.add_child(status)
		_statuses[adventurer] = status
		var row := PanelContainer.new()
		row.add_child(words)
		_list.add_child(row)


func show_dispatch(dispatch: Dispatch, now: int) -> void:
	for adventurer: String in _statuses:
		var status := _statuses[adventurer]
		status.text = dispatch.status(adventurer, now)
		if dispatch.injury_left(adventurer, now) > 0:
			status.theme_type_variation = &"Alert"
		elif dispatch.can_go(adventurer, now):
			status.theme_type_variation = &"Ok"
		else:
			status.theme_type_variation = &"Secondary"


func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.theme_type_variation = variation
	return label
