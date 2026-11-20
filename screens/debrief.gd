class_name Debrief
extends Control

## The player read the debrief and filed it away.
signal done_pressed
## The player tapped `adventurer`, one of the party, to see them.
signal adventurer_pressed(adventurer: String)

@onready var _quest: Label = $Scroll/Box/Header/Words/Quest
@onready var _result: Label = $Scroll/Box/Header/Result
@onready var _members: VBoxContainer = $Scroll/Box/Who/Members
@onready var _revealed: Label = $Scroll/Box/Revealed
@onready var _gold: Label = $Scroll/Box/Brought/Rows/Row/Gold
@onready var _items: VBoxContainer = $Scroll/Box/Brought/Rows/Items


func _ready() -> void:
	($Scroll/Box/Done as Button).pressed.connect(done_pressed.emit)


## Shows `debrief`, one of `dispatch`'s debriefs, with who of its party has a level-up waiting and
## which of its items reading it now would lose to a full stash.
func show_debrief(debrief: Dictionary, dispatch: Dispatch) -> void:
	var adventurers := dispatch.adventurers
	_quest.text = Dispatch.QUESTS[debrief["quest"]]["name"]
	_result.text = "Success" if debrief["success"] else "Failed"
	_result.theme_type_variation = &"SuccessChip" if debrief["success"] else &"FailedChip"
	for row: Node in _members.get_children():
		_members.remove_child(row)
		row.queue_free()
	var injured: Dictionary = debrief["injured"]
	# A debrief saved before damage was kept says "unhurt".
	var damage: Dictionary = debrief.get("damage", {})
	for adventurer: String in debrief["party"]:
		var name_label := Label.new()
		name_label.text = adventurers.roster[adventurer]["name"]
		name_label.theme_type_variation = &"RowTitle"
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var state := Label.new()
		var dealt: int = damage.get(adventurer, 0)
		state.text = "took %d damage" % dealt if dealt > 0 else "unhurt"
		if adventurer in injured:
			state.text += " · injured · " + Duration.label(injured[adventurer])
		state.theme_type_variation = &"Secondary"
		state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
		line.add_child(QuestBoard.token(adventurer, adventurers.roster))
		line.add_child(name_label)
		line.add_child(state)
		line.add_child(growth)
		var row := PanelContainer.new()
		row.theme_type_variation = &"ProgressRow"
		row.add_child(line)
		# Over the whole row, so a tap anywhere on it opens the member.
		var open := Button.new()
		open.flat = true
		open.pressed.connect(adventurer_pressed.emit.bind(adventurer))
		row.add_child(open)
		_members.add_child(row)
	# A debrief saved before challenges revealed none.
	var revealed: PackedStringArray = debrief.get("revealed", PackedStringArray())
	_revealed.text = "Revealed: " + ", ".join(revealed)
	_revealed.visible = not revealed.is_empty()
	_gold.text = "+%d" % debrief["gold"]
	for line: Node in _items.get_children():
		line.queue_free()
	var loot := dispatch.debrief_loot(debrief)
	for item: String in loot["loot"]:
		_items.add_child(_item_line(item, ""))
	for item: String in loot["lost"]:
		_items.add_child(_item_line(item, "The stash was full: lost"))
	_items.visible = _items.get_child_count() > 0


# An item's icon and name in its quality's colour, with `note` after it when there is one.
func _item_line(item: String, note: String) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 24)
	line.add_child(Adventurer.item_icon(item, 3))
	var name_label := Adventurer.item_name(item)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(name_label)
	if not note.is_empty():
		var lost := Label.new()
		lost.text = note
		lost.theme_type_variation = &"Alert"
		lost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line.add_child(lost)
	return line
