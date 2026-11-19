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


## Shows `debrief`, one of Dispatch.debriefs, with who of its party has a level-up waiting in
## `adventurers`.
func show_debrief(debrief: Dictionary, adventurers: Adventurers) -> void:
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
		# A debrief saved before XP was kept says +0: that party came home without any.
		var xp := Label.new()
		xp.text = "+%d XP" % debrief.get("xp", 0)
		xp.theme_type_variation = &"XpText"
		xp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var growth := VBoxContainer.new()
		growth.alignment = BoxContainer.ALIGNMENT_CENTER
		growth.add_child(xp)
		if adventurers.level_up_ready(adventurer):
			var ready := Label.new()
			ready.text = "Level up ready"
			ready.theme_type_variation = &"GoldText"
			ready.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			growth.add_child(ready)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 32)
		line.add_child(QuestBoard.token(adventurer))
		line.add_child(name_label)
		line.add_child(state)
		line.add_child(growth)
		var row := PanelContainer.new()
		row.theme_type_variation = &"ProgressRow"
		row.add_child(line)
		_members.add_child(row)
	_gold.text = "+%d" % debrief["gold"]
