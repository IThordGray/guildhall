class_name Debrief
extends Control

## The player read the debrief and filed it away.
signal done_pressed

@onready var _quest: Label = $Box/Header/Words/Quest
@onready var _result: Label = $Box/Header/Result
@onready var _members: VBoxContainer = $Box/Who/Members
@onready var _gold: Label = $Box/Brought/Row/Gold


func _ready() -> void:
	($Box/Done as Button).pressed.connect(done_pressed.emit)


## Shows `debrief`, one of Dispatch.debriefs.
func show_debrief(debrief: Dictionary) -> void:
	_quest.text = Dispatch.QUESTS[debrief["quest"]]["name"]
	_result.text = "Success" if debrief["success"] else "Failed"
	_result.theme_type_variation = &"SuccessChip" if debrief["success"] else &"FailedChip"
	for row: Node in _members.get_children():
		row.queue_free()
	var injured: Dictionary = debrief["injured"]
	for adventurer: String in debrief["party"]:
		var name_label := Label.new()
		name_label.text = Dispatch.ADVENTURERS[adventurer]["name"]
		name_label.theme_type_variation = &"RowTitle"
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var state := Label.new()
		state.text = "injured · " + Duration.label(injured[adventurer]) if adventurer in injured else "unhurt"
		state.theme_type_variation = &"Secondary"
		state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 32)
		line.add_child(QuestBoard.token(adventurer))
		line.add_child(name_label)
		line.add_child(state)
		var row := PanelContainer.new()
		row.theme_type_variation = &"ProgressRow"
		row.add_child(line)
		_members.add_child(row)
	_gold.text = "+%d" % debrief["gold"]
