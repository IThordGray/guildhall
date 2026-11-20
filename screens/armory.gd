class_name Armory
extends Control

## The player is done looking at the guild's gear.
signal back_pressed

## The gear worn and the stash, as shown, so the lists are rebuilt only when they change.
var _shown: Array = []

@onready var _stash_section: Label = $Box/Scroll/Lists/StashSection
@onready var _stash: VBoxContainer = $Box/Scroll/Lists/Stash/Items
@onready var _worn: VBoxContainer = $Box/Scroll/Lists/Worn


func _ready() -> void:
	($Box/Back as Button).pressed.connect(back_pressed.emit)


## Shows every item in `adventurers`' stash, and what each of them wears.
func show_gear(adventurers: Adventurers) -> void:
	var gear := adventurers.gear
	var shown := [gear.worn.duplicate(true), gear.stash.duplicate()]
	if shown == _shown:
		return
	_shown = shown
	_stash_section.text = "STASH · %d / %d" % [gear.stash.size(), Gear.STASH_CAP]
	for list: Node in [_stash, _worn]:
		for row: Node in list.get_children():
			list.remove_child(row)
			row.queue_free()
	if gear.stash.is_empty():
		var empty := Label.new()
		empty.text = "Empty"
		empty.theme_type_variation = &"Caption"
		var row := PanelContainer.new()
		row.theme_type_variation = &"ProgressRow"
		row.add_child(empty)
		_stash.add_child(row)
	for item: String in gear.stash:
		var row := PanelContainer.new()
		row.theme_type_variation = &"ProgressRow"
		row.add_child(_item_line(item, 3))
		_stash.add_child(row)
	for adventurer: String in adventurers.roster:
		var who := HBoxContainer.new()
		who.add_theme_constant_override("separation", 32)
		who.add_child(QuestBoard.token(adventurer, adventurers.roster))
		var name_label := Label.new()
		name_label.text = adventurers.roster[adventurer]["name"]
		name_label.theme_type_variation = &"RowTitle"
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		who.add_child(name_label)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 16)
		box.add_child(who)
		var worn: Dictionary = gear.worn[adventurer]
		for slot: String in Gear.SLOTS:
			if worn.has(slot):
				box.add_child(_item_line(worn[slot], 2))
		var card := PanelContainer.new()
		card.add_child(box)
		_worn.add_child(card)


# `item`'s icon at `scale`, its name and its bonus.
static func _item_line(item: String, scale: int) -> HBoxContainer:
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_child(Adventurer.item_name(item))
	words.add_child(Adventurer.bonus_label(item))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 32)
	line.add_child(Adventurer.item_icon(item, scale))
	line.add_child(words)
	return line
