class_name Roster
extends Control

@export var row_style: StyleBox

var _statuses: Dictionary[String, Label] = {}

@onready var _list: VBoxContainer = $List


func _ready() -> void:
	for adventurer: String in Dispatch.ADVENTURERS:
		var info: Dictionary = Dispatch.ADVENTURERS[adventurer]
		var words := VBoxContainer.new()
		words.add_child(_label(info["name"], 52, Color.WHITE))
		words.add_child(_label("%s · rank %s · power %d" % [info["class"], info["rank"], info["power"]], 44, Color(1, 0.84, 0.4)))
		var status := _label("", 44, Color(0.8, 0.8, 0.8))
		words.add_child(status)
		_statuses[adventurer] = status
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", row_style)
		row.add_child(words)
		_list.add_child(row)


func show_dispatch(dispatch: Dispatch, now: int) -> void:
	for adventurer: String in _statuses:
		_statuses[adventurer].text = dispatch.status(adventurer, now)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
