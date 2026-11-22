class_name Roster
extends Control

## The player tapped `adventurer`, a key of Adventurers.roster, to see them.
signal adventurer_pressed(adventurer: String)
## The player asked to hire the candidate in `slot` of Recruits.candidates.
signal hire_pressed(slot: int)
## The player asked to see the guild's gear.
signal armory_pressed
## The player accepted the walk-in into a free bed.
signal accept_pressed
## The player turned the walk-in away.
signal turn_away_pressed
## The player asked to swap the walk-in for someone in the guild, every bed being taken.
signal swap_pressed

## The space above and below the figure in an adventurer's row.
const ROW_PADDING_PX: int = 22

## The adventurers the rows were built for, in roster order, so they are rebuilt only when someone
## joins or leaves.
var _built: Array = []
var _statuses: Dictionary[String, Label] = {}
var _details: Dictionary[String, Label] = {}
var _healths: Dictionary[String, HBoxContainer] = {}
## The candidates the candidate rows were built for, so they are rebuilt only when one is hired or
## arrives; the parts that change without that: by slot, each candidate's hire button and why it
## can't be pressed, and the one line under them for the empty slots, the soonest refill.
var _candidates_shown: Array[Dictionary] = []
var _hires: Dictionary[int, Button] = {}
var _hire_reasons: Dictionary[int, Label] = {}
var _countdown: Label
## The walk-in the card was built for, so it is rebuilt only when one arrives or goes; its Accept,
## shown while a bed is free, and its Swap, shown while none is.
var _walk_in_shown: Dictionary = {}
var _accept: Button
var _swap: Button

@onready var _list: VBoxContainer = $Scroll/Box/List
@onready var _beds: Label = $Scroll/Box/Header/Beds
@onready var _candidates: VBoxContainer = $Scroll/Box/Candidates
@onready var _walk_in: VBoxContainer = $Scroll/Box/WalkIn


func _ready() -> void:
	($Scroll/Box/Header/Armory as Button).pressed.connect(armory_pressed.emit)


func show_dispatch(dispatch: Dispatch, now: int) -> void:
	var roster := dispatch.adventurers.roster
	if roster.keys() != _built:
		_build(dispatch.adventurers)
	for adventurer: String in _statuses:
		_details[adventurer].text = details_line(dispatch.adventurers, adventurer)
		var status := _statuses[adventurer]
		status.text = dispatch.status(adventurer, now)
		status.theme_type_variation = status_look(dispatch, adventurer, now)
		Adventurer.show_health(_healths[adventurer], adventurer, dispatch, now)


## Shows how many beds `adventurers` fill of `beds`, and `recruits`' candidates at `now`: each with
## a hire button, disabled with the reason when `gold` or a bed is short; then, while a slot is
## empty, the soonest refill. `hall` is what a reason may suggest building.
func show_recruits(recruits: Recruits, adventurers: Adventurers, gold: Gold, beds: int, hall: Hall, now: int) -> void:
	_beds.text = "%d adventurers · %d beds" % [adventurers.roster.size(), beds]
	if recruits.candidates != _candidates_shown:
		_build_candidates(recruits.candidates)
	for slot: int in _hires:
		var reason := Recruits.refusal(adventurers, gold, beds, Recruits.hire_gold(recruits.candidates[slot]), hall)
		_hires[slot].disabled = not reason.is_empty()
		_hire_reasons[slot].text = reason
		_hire_reasons[slot].visible = not reason.is_empty()
	var left := recruits.seconds_to_next_refill(now)
	_countdown.visible = left >= 0
	_countdown.text = "New candidate in " + Duration.label(left)


## Shows `walk_in`, as WalkIns keeps them, at the top: Accept while `free_bed`, else Swap; nothing
## while nobody waits.
func show_walk_in(walk_in: Dictionary, free_bed: bool) -> void:
	if walk_in != _walk_in_shown:
		_build_walk_in(walk_in)
	if not walk_in.is_empty():
		_accept.visible = free_bed
		_swap.visible = not free_bed


## `adventurer`'s title, rank and level, in words for the player.
static func details_line(adventurers: Adventurers, adventurer: String) -> String:
	return "%s · rank %s · level %d" % [adventurers.title(adventurer), adventurers.roster[adventurer]["rank"], adventurers.levels[adventurer]]


## The adventurer `step` places after `adventurer` in `roster` order (Adventurers.roster), wrapping
## around at the ends.
static func adventurer_after(adventurer: String, step: int, roster: Dictionary) -> String:
	var order := roster.keys()
	return order[posmod(order.find(adventurer) + step, order.size())]


## How `adventurer`'s status reads at `now`: hurt, free to go, or busy.
static func status_look(dispatch: Dispatch, adventurer: String, now: int) -> StringName:
	if dispatch.injury_left(adventurer, now) > 0:
		return &"Alert"
	if dispatch.can_go(adventurer, now):
		return &"Ok"
	return &"Secondary"


# One row per adventurer in `adventurers`' roster: their figure in their gear, name, status, details
# and health.
func _build(adventurers: Adventurers) -> void:
	var roster := adventurers.roster
	_built = roster.keys()
	for row: Node in _list.get_children():
		_list.remove_child(row)
		row.queue_free()
	_statuses.clear()
	_details.clear()
	_healths.clear()
	for adventurer: String in roster:
		var row := adventurer_row(adventurer, adventurers)
		_statuses[adventurer] = row.find_child("Status", true, false)
		_details[adventurer] = row.find_child("Details", true, false)
		_healths[adventurer] = row.find_child("Health", true, false)
		row.pressed.connect(adventurer_pressed.emit.bind(adventurer))
		_list.add_child(row)


## A roster row for `adventurer` of `adventurers`: their figure in their gear, their name, and the
## empty labels "Status" and "Details" and the `Adventurer.health_row` "Health" for whoever shows it
## to fill.
static func adventurer_row(adventurer: String, adventurers: Adventurers) -> Button:
	var who: Dictionary = adventurers.roster[adventurer]
	var name_line := HBoxContainer.new()
	name_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := _label(who["name"], &"RowTitle")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_line.add_child(name_label)
	var status := _label("", &"Secondary")
	status.name = "Status"
	status.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_line.add_child(status)
	var details := _label("", &"Secondary")
	details.name = "Details"
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_child(name_line)
	words.add_child(details)
	var health := Adventurer.health_row()
	health.name = "Health"
	words.add_child(health)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 32)
	var figure := TextureRect.new()
	figure.texture = QuestBoard.figure(Faces.seed_of(adventurer, who), adventurers.gear.worn[adventurer])
	figure.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	figure.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(figure)
	line.add_child(words)
	var row := Button.new()
	# A button does not fit its children, so the row is made tall enough for the figure.
	row.custom_minimum_size = Vector2(0, figure.texture.get_height() + 2 * ROW_PADDING_PX)
	row.add_child(line)
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 36
	line.offset_right = -36
	return row


# One row per filled slot of `candidates`, in slot order: the candidate, what they show of
# themselves and a hire button, which a tap anywhere on the row presses. Then the refill line.
func _build_candidates(candidates: Array[Dictionary]) -> void:
	_candidates_shown = candidates.duplicate()
	for row: Node in _candidates.get_children():
		_candidates.remove_child(row)
		row.queue_free()
	_hires.clear()
	_hire_reasons.clear()
	for slot: int in candidates.size():
		var candidate := candidates[slot]
		if candidate.is_empty():
			continue
		var who: Dictionary = candidate["who"]
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		words.add_child(_label(who["name"], &"RowTitle"))
		words.add_child(_label("%s · rank %s" % [Recruits.title(candidate), who["rank"]], &"Secondary"))
		var hire := Button.new()
		hire.text = "Hire · %dg" % Recruits.hire_gold(candidate)
		hire.theme_type_variation = &"GoldButton"
		hire.custom_minimum_size = Vector2(0, 122)
		hire.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hire.pressed.connect(hire_pressed.emit.bind(slot))
		_hires[slot] = hire
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 32)
		line.add_child(QuestBoard.face_token(who["face_seed"]))
		line.add_child(words)
		line.add_child(hire)
		# The stats and the reason a hire is refused take the row's full width, beside nothing.
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 16)
		box.add_child(line)
		box.add_child(_label(Recruits.stats_line(candidate), &"Secondary"))
		_hire_reasons[slot] = _label("", &"Alert")
		box.add_child(_hire_reasons[slot])
		var row := PanelContainer.new()
		row.add_child(box)
		_candidates.add_child(Touch.whole_card(row, hire))
	_countdown = _label("", &"Secondary")
	_candidates.add_child(_countdown)


# The walk-in's card, like a candidate's: a Walk-in tag, their face, title, level, what they show of
# their stats and their weapon, with Turn away and Accept or Swap. Two actions, so no whole-card tap.
func _build_walk_in(walk_in: Dictionary) -> void:
	_walk_in_shown = walk_in.duplicate()
	for card: Node in _walk_in.get_children():
		_walk_in.remove_child(card)
		card.queue_free()
	_walk_in.visible = not walk_in.is_empty()
	if walk_in.is_empty():
		return
	var who: Dictionary = walk_in["who"]
	var name_line := HBoxContainer.new()
	name_line.add_theme_constant_override("separation", 22)
	var name_label := _label(who["name"], &"RowTitle")
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_line.add_child(name_label)
	var tag := _label("Walk-in", &"Chip")
	tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_line.add_child(tag)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_child(name_line)
	words.add_child(_label("%s · rank %s · level %d" % [Recruits.title(walk_in), who["rank"], walk_in.get("level", 1)], &"Secondary"))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 32)
	line.add_child(QuestBoard.face_token(who["face_seed"], walk_in["worn"]))
	line.add_child(words)
	var weapon := HBoxContainer.new()
	weapon.add_theme_constant_override("separation", 16)
	var item: String = walk_in["worn"]["weapon"]
	weapon.add_child(Adventurer.item_icon(item, 3))
	var item_name := Adventurer.item_name(item)
	item_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	weapon.add_child(item_name)
	var turn_away := Button.new()
	turn_away.text = "Turn away"
	turn_away.theme_type_variation = &"OutlineButton"
	turn_away.pressed.connect(turn_away_pressed.emit)
	_accept = Button.new()
	_accept.text = "Accept"
	_accept.pressed.connect(accept_pressed.emit)
	_swap = Button.new()
	_swap.text = "Swap"
	_swap.pressed.connect(swap_pressed.emit)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 28)
	for button: Button in [turn_away, _accept, _swap]:
		button.custom_minimum_size = Vector2(0, 122)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(button)
	_accept.theme_type_variation = &"GoldButton"
	_swap.theme_type_variation = &"GoldButton"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.add_child(line)
	box.add_child(_label(Recruits.stats_line(walk_in), &"Secondary"))
	box.add_child(weapon)
	box.add_child(buttons)
	var card := PanelContainer.new()
	card.add_child(box)
	_walk_in.add_child(card)


static func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.theme_type_variation = variation
	return label
