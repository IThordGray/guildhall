class_name QuestBoard
extends Control

## The player asked to send the party on `quest`, a key of Dispatch.QUESTS.
signal send_pressed(quest: String)

@export var row_style: StyleBox

var _send_buttons: Dictionary[String, Button] = {}

@onready var _status: Label = $Box/Status
@onready var _list: VBoxContainer = $Box/List


func _ready() -> void:
	for quest: String in Dispatch.QUESTS:
		var info: Dictionary = Dispatch.QUESTS[quest]
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		words.add_child(_label(info["name"], 52, Color.WHITE))
		words.add_child(_label("%s · %d gold" % [Duration.label(info["seconds"]), info["gold"]], 44, Color(1, 0.84, 0.4)))
		var send := Button.new()
		send.custom_minimum_size = Vector2(360, 140)
		send.add_theme_font_size_override("font_size", 48)
		send.pressed.connect(send_pressed.emit.bind(quest))
		_send_buttons[quest] = send
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 32)
		line.add_child(words)
		line.add_child(send)
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", row_style)
		row.add_child(line)
		_list.add_child(row)


func show_dispatch(dispatch: Dispatch, now: int) -> void:
	var left := dispatch.seconds_left(now)
	if left > 0:
		_status.text = "Party out: %s · %s" % [Dispatch.QUESTS[dispatch.quest]["name"], Duration.label(left)]
	else:
		_status.text = "Party is home"
	var reason := dispatch.refusal(now)
	for quest: String in _send_buttons:
		var send := _send_buttons[quest]
		send.disabled = not reason.is_empty()
		send.text = "Send party" if reason.is_empty() else reason


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
