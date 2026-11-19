class_name QuestBoard
extends Control

## The player asked to send a party on `quest`, a key of Dispatch.QUESTS.
signal send_pressed(quest: String)

var _rows: Dictionary[String, Control] = {}
## The quests shown, in board order, so the rows change only when the board does.
var _shown: PackedStringArray = PackedStringArray()

@onready var _status: Label = $Box/Status
@onready var _result: Label = $Box/Result
@onready var _list: VBoxContainer = $Box/List
@onready var _empty: Label = $Box/Empty


func _ready() -> void:
	for quest: String in Dispatch.QUESTS:
		var info: Dictionary = Dispatch.QUESTS[quest]
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		words.add_child(_label(info["name"], &"Heading"))
		words.add_child(_label("%s · %d gold · difficulty %d" % [Duration.label(info["seconds"]), info["gold"], info["difficulty"]], &"Meta"))
		var send := Button.new()
		send.text = "Send party"
		send.theme_type_variation = &"GoldButton"
		send.custom_minimum_size = Vector2(0, 122)
		send.pressed.connect(send_pressed.emit.bind(quest))
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 32)
		line.add_child(words)
		line.add_child(send)
		var row := PanelContainer.new()
		row.visible = false
		row.add_child(line)
		_rows[quest] = row
		_list.add_child(row)


## Shows `quests`, the board in board order, and `dispatch` at `now`.
func show_board(quests: PackedStringArray, dispatch: Dispatch, now: int) -> void:
	var out := PackedStringArray()
	for outing: Dictionary in dispatch.outings:
		out.append("Party out: %s · %s" % [Dispatch.QUESTS[outing["quest"]]["name"], Duration.label(dispatch.seconds_left(outing, now))])
	_status.text = "Party is home" if out.is_empty() else "\n".join(out)
	_result.text = dispatch.last_return
	_result.visible = not dispatch.last_return.is_empty()
	if quests == _shown:
		return
	_shown = quests
	for quest: String in _rows:
		_rows[quest].visible = quest in quests
	for i: int in quests.size():
		_list.move_child(_rows[quests[i]], i)
	_empty.visible = quests.is_empty()


func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.theme_type_variation = variation
	return label
