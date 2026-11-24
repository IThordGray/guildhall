class_name Roster
extends Control

## The player tapped `adventurer`, a key of Adventurers.roster, to see them.
signal adventurer_pressed(adventurer: String)
## The player asked to hire the candidate in `slot` of Recruits.candidates.
signal hire_pressed(slot: int)
## The player tapped the candidate in `slot` of Recruits.candidates, or the walk-in for WALK_IN, to
## see them.
signal visitor_pressed(slot: int)
## The player asked to see the guild's gear.
signal armory_pressed
## The player accepted the walk-in into a free bed.
signal accept_pressed
## The player turned the walk-in away.
signal turn_away_pressed
## The player asked to swap the walk-in for someone in the guild, every bed being taken.
signal swap_pressed
## The player rolled a new name for the party with id `party` (Parties).
signal reroll_pressed(party: String)
## The player typed `typed` as the name of the party with id `party`.
signal name_typed(party: String, typed: String)

## How tall an adventurer's row is: the design's 52 dp, so the whole guild fits on a small phone.
const ROW_HEIGHT_PX: int = 144
## The space between a row's left and right edges and what it shows: the design's 8 and 12 dp.
const ROW_INSET_LEFT_PX: int = 22
const ROW_INSET_RIGHT_PX: int = 33
## The space between a row's face, words and buttons.
const ROW_GAP_PX: int = 28
## How tall a row's health bar is: the design's 4 dp.
const HEALTH_BAR_PX: int = 11
## The small text of a row's status and its small buttons, and of its health numbers.
const SMALL_FONT_PX: int = 33
const NUMBERS_FONT_PX: int = 30
## How tall a row's small buttons are: the design's 32 dp.
const SMALL_BUTTON_PX: int = 88
## What a disabled row's contents are tinted, so it reads as not pickable.
const DISABLED_ROW_TINT: Color = Color(1, 1, 1, 0.4)
## How tall the free-beds line under the rows is: the design's 40 dp.
const FREE_ROW_HEIGHT_PX: int = 110
## The size of a party's name in its card's header, and how much of the dice button the die fills.
const PARTY_NAME_FONT_PX: int = 39
const DIE_SHARE: float = 0.5
## As wide as QuestBoard's face token, so the free-beds "+" sits under the faces.
const FACE_COLUMN_PX: int = 80
## Who a visitor is, beside the candidates' slots: the walk-in, or nobody.
const WALK_IN: int = -1
const NO_VISITOR: int = -2

## The roster and the parties' members the rows were built for, so they are rebuilt only when
## someone joins, leaves or moves.
var _built: Array = []
## Each adventurer's row, and each party's name and rank badge, by the party's id.
var _rows: Dictionary[String, Button] = {}
var _names: Dictionary[String, Button] = {}
var _ranks: Dictionary[String, Label] = {}
var _statuses: Dictionary[String, Label] = {}
var _details: Dictionary[String, Label] = {}
var _healths: Dictionary[String, HBoxContainer] = {}
var _level_ups: Dictionary[String, Label] = {}
## The adventurer whose row is marked as the one shown beside the roster; "" for none. Or else the
## visitor whose card is: a candidate's slot, WALK_IN, or NO_VISITOR.
var _marked: String = ""
var _marked_visitor: int = NO_VISITOR
## The quiet line under the cards while beds outnumber the roster, and its words.
var _free: Control
var _free_beds: Label
## The candidates the candidate rows were built for, so they are rebuilt only when one is hired or
## arrives; the parts that change without that: by slot, each candidate's hire button and why it
## can't be pressed.
var _candidates_shown: Array[Dictionary] = []
var _candidate_cards: Dictionary[int, PanelContainer] = {}
var _hires: Dictionary[int, Button] = {}
var _hire_reasons: Dictionary[int, Label] = {}
## The walk-in the card was built for, so it is rebuilt only when one arrives or goes; its Accept,
## shown while a bed is free, and its Swap, shown while none is.
var _walk_in_shown: Dictionary = {}
var _walk_in_card: PanelContainer
var _accept: Button
var _swap: Button

## One card per party, then the reserves' card under its label, shown while anyone is in reserve.
@onready var _parties: VBoxContainer = $Scroll/Box/Parties
@onready var _reserves_header: Label = $Scroll/Box/ReservesHeader
@onready var _reserves: VBoxContainer = $Scroll/Box/Reserves
@onready var _beds: Label = $Scroll/Box/Header/Beds
@onready var _candidates: VBoxContainer = $Scroll/Box/Candidates
## The soonest refill, beside the candidates' section label, while a slot is empty.
@onready var _countdown: Label = $Scroll/Box/CandidatesHeader/Countdown
@onready var _walk_in: VBoxContainer = $Scroll/Box/WalkIn


func _ready() -> void:
	($Scroll/Box/Header/Armory as Button).pressed.connect(armory_pressed.emit)
	_reserves.draw.connect(QuestBoard.draw_card.bind(_reserves))
	_reserves.sort_children.connect(_reserves.queue_redraw)
	_build_free_row()


## Shows `dispatch` at `now`: each party's name and rank, and each adventurer's row.
func show_dispatch(dispatch: Dispatch, now: int) -> void:
	var adventurers := dispatch.adventurers
	var built := [adventurers.roster.keys(), _groups(adventurers.parties)]
	if built != _built:
		_build(adventurers)
		_built = built
	for party: String in _names:
		_names[party].text = adventurers.parties.party(party)["name"]
		_ranks[party].text = adventurers.parties.rank(party, adventurers.roster)
	for adventurer: String in _statuses:
		_details[adventurer].text = details_line(dispatch.adventurers, adventurer)
		_level_ups[adventurer].visible = dispatch.adventurers.level_up_ready(adventurer)
		var status := _statuses[adventurer]
		status.text = dispatch.status(adventurer, now)
		status.theme_type_variation = status_look(dispatch, adventurer, now)
		Adventurer.show_health(_healths[adventurer], adventurer, dispatch, now)


## Shows how many beds `adventurers` fill of `beds`, and `recruits`' candidates at `now`: each with
## a hire button, disabled with the reason when `gold` or a bed is short; and, while a slot is empty,
## the soonest refill. `hall` is what a reason may suggest building.
func show_recruits(recruits: Recruits, adventurers: Adventurers, gold: Gold, beds: int, hall: Hall, now: int) -> void:
	var filled := adventurers.roster.size()
	_beds.text = "%d / %d beds" % [filled, beds]
	_free.visible = beds > filled
	_free_beds.text = "%d bed free" % (beds - filled) if beds - filled == 1 else "%d beds free" % (beds - filled)
	if recruits.candidates != _candidates_shown:
		_build_candidates(recruits.candidates)
	for slot: int in _hires:
		var reason := Recruits.refusal(adventurers, gold, beds, Recruits.hire_gold(recruits.candidates[slot]), hall)
		_hires[slot].disabled = not reason.is_empty()
		_hire_reasons[slot].text = reason
		_hire_reasons[slot].visible = not reason.is_empty()
	var left := recruits.seconds_to_next_refill(now)
	_countdown.visible = left >= 0
	_countdown.text = "next in " + Duration.label(left)


## Shows `walk_in`, as WalkIns keeps them, under the roster: Accept while `free_bed`, else Swap;
## nothing while nobody waits.
func show_walk_in(walk_in: Dictionary, free_bed: bool) -> void:
	if walk_in != _walk_in_shown:
		_build_walk_in(walk_in)
	if not walk_in.is_empty():
		_accept.visible = free_bed
		_swap.visible = not free_bed


## Marks `adventurer`'s row as the one shown beside the roster, or else the card of `visitor`, a
## candidate's slot or WALK_IN, and no other; "" and NO_VISITOR mark none.
func mark(adventurer: String, visitor: int = NO_VISITOR) -> void:
	if adventurer == _marked and visitor == _marked_visitor:
		return
	_marked = adventurer
	_marked_visitor = visitor
	_show_mark()


func _show_mark() -> void:
	for adventurer: String in _rows:
		_rows[adventurer].theme_type_variation = &"ListRowChosen" if adventurer == _marked else &"ListRow"
	for slot: int in _candidate_cards:
		_candidate_cards[slot].theme_type_variation = &"RowCardChosen" if slot == _marked_visitor else &""
	if _walk_in_card != null:
		_walk_in_card.theme_type_variation = &"RowCardChosen" if _marked_visitor == WALK_IN else &""


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


# Each party's id and members, in the order the parties were made: what the cards are built from.
static func _groups(parties: Parties) -> Array:
	var groups := []
	for party: Dictionary in parties.parties:
		groups.append([party["id"], party["members"].duplicate()])
	return groups


# One card per party of `adventurers`, its header over a row per member; then the reserves' card,
# a row per reserve in roster order, shown with its label only while anyone is in reserve. Each row
# shows the adventurer's face, name, details, health and status.
func _build(adventurers: Adventurers) -> void:
	for card: Node in _parties.get_children() + _reserves.get_children():
		card.get_parent().remove_child(card)
		card.queue_free()
	for parts: Dictionary in [_rows, _names, _ranks, _statuses, _details, _healths, _level_ups]:
		parts.clear()
	for party: Dictionary in adventurers.parties.parties:
		var card := VBoxContainer.new()
		card.theme_type_variation = &"RowList"
		card.draw.connect(QuestBoard.draw_card.bind(card))
		# Rows laid out after the first draw move the lines between them.
		card.sort_children.connect(card.queue_redraw)
		card.add_child(_party_header(party["id"]))
		for adventurer: String in party["members"]:
			card.add_child(_row(adventurer, adventurers))
		_parties.add_child(card)
	var reserves := adventurers.parties.reserves(adventurers.roster)
	for adventurer: String in reserves:
		_reserves.add_child(_row(adventurer, adventurers))
	_reserves.visible = not reserves.is_empty()
	_reserves_header.visible = _reserves.visible
	_show_mark()


# `adventurer`'s row, its parts kept to show them again, a tap on it opening them.
func _row(adventurer: String, adventurers: Adventurers) -> Button:
	var row := adventurer_row(adventurer, adventurers)
	_rows[adventurer] = row
	_statuses[adventurer] = row.find_child("Status", true, false)
	_details[adventurer] = row.find_child("Details", true, false)
	_healths[adventurer] = row.find_child("Health", true, false)
	_level_ups[adventurer] = row.find_child("LevelUp", true, false)
	row.pressed.connect(adventurer_pressed.emit.bind(adventurer))
	return row


# A party card's header, its name filled in by show_dispatch: the name, a tap on which swaps it for
# a field to type a new one in, kept on Enter or once the field loses focus; the dice that roll a
# new name; and the party's rank badge.
func _party_header(party: String) -> MarginContainer:
	var name_button := Button.new()
	name_button.flat = true
	name_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# A long name wraps rather than being cut, in the narrow landscape column.
	name_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_button.add_theme_font_size_override(&"font_size", PARTY_NAME_FONT_PX)
	var field := LineEdit.new()
	field.max_length = Parties.NAME_MOST_CHARS
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	field.add_theme_font_size_override(&"font_size", PARTY_NAME_FONT_PX)
	field.visible = false
	name_button.pressed.connect(func() -> void:
		field.text = name_button.text
		name_button.visible = false
		field.visible = true
		field.grab_focus()
		field.select_all())
	field.text_submitted.connect(func(_typed: String) -> void: field.release_focus())
	field.focus_exited.connect(func() -> void:
		field.visible = false
		name_button.visible = true
		name_typed.emit(party, field.text))
	var dice := Button.new()
	dice.theme_type_variation = &"OutlineButton"
	dice.custom_minimum_size = Vector2.ONE * SMALL_BUTTON_PX
	dice.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dice.draw.connect(_draw_die.bind(dice))
	dice.pressed.connect(reroll_pressed.emit.bind(party))
	var rank := QuestBoard.chip("", &"Pill")
	rank.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_names[party] = name_button
	_ranks[party] = rank
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 16)
	for part: Control in [name_button, field, rank, dice]:
		line.add_child(part)
	var header := MarginContainer.new()
	header.custom_minimum_size.y = FREE_ROW_HEIGHT_PX
	header.add_theme_constant_override("margin_left", ROW_INSET_LEFT_PX)
	header.add_theme_constant_override("margin_right", ROW_INSET_RIGHT_PX)
	header.add_child(line)
	return header


# A die's five face on `dice`: a rounded square with a pip in each corner and one in the middle.
static func _draw_die(dice: Button) -> void:
	var colour := dice.get_theme_color(&"font_color")
	var side := dice.size.y * DIE_SHARE
	var face := Rect2(dice.size / 2 - Vector2.ONE * side / 2, Vector2.ONE * side)
	dice.draw_rect(face, colour, false, 3.0)
	for at: Vector2 in [Vector2(0.25, 0.25), Vector2(0.75, 0.25), Vector2(0.5, 0.5), Vector2(0.25, 0.75), Vector2(0.75, 0.75)]:
		dice.draw_circle(face.position + at * side, side / 11, colour)


# The quiet line kept after the cards, whatever the roster: "+  N beds free", not tappable.
func _build_free_row() -> void:
	var plus := _label("+", &"Caption")
	plus.custom_minimum_size.x = FACE_COLUMN_PX
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_free_beds = _label("", &"Caption")
	_free_beds.autowrap_mode = TextServer.AUTOWRAP_OFF
	_free_beds.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", ROW_GAP_PX)
	line.add_child(plus)
	line.add_child(_free_beds)
	_free = Control.new()
	_free.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_free.custom_minimum_size.y = FREE_ROW_HEIGHT_PX
	_free.visible = false
	_free.add_child(line)
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = ROW_INSET_LEFT_PX
	_reserves.add_sibling(_free)


## A compact roster row for `adventurer` of `adventurers`, one tap target: their face; their name,
## the hidden "LevelUp" pill and the empty "Details" label over the `Adventurer.health_row`
## "Health"; and the empty "Status" label, for whoever shows it to fill.
static func adventurer_row(adventurer: String, adventurers: Adventurers) -> Button:
	var who: Dictionary = adventurers.roster[adventurer]
	var name_label := _label(who["name"], &"RowTitle")
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var level_up := _label("LV UP", &"LevelUp")
	level_up.name = "LevelUp"
	level_up.autowrap_mode = TextServer.AUTOWRAP_OFF
	level_up.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	level_up.visible = false
	var details := QuestBoard.one_line("", &"Caption")
	details.name = "Details"
	var status := _label("", &"Secondary")
	status.name = "Status"
	status.autowrap_mode = TextServer.AUTOWRAP_OFF
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override(&"font_size", SMALL_FONT_PX)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 16)
	for part: Label in [name_label, level_up, details, status]:
		top.add_child(part)
	var health := Adventurer.health_row()
	health.name = "Health"
	(health.get_child(0) as Control).custom_minimum_size.y = HEALTH_BAR_PX
	var numbers := health.get_child(1) as Label
	numbers.custom_minimum_size.x = 0.0
	numbers.add_theme_font_size_override(&"font_size", NUMBERS_FONT_PX)
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_child(top)
	words.add_child(health)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", ROW_GAP_PX)
	line.add_child(QuestBoard.face_token(Faces.seed_of(adventurer, who), adventurers.gear.worn[adventurer]))
	line.add_child(words)
	var row := Button.new()
	row.theme_type_variation = &"ListRow"
	# A button does not fit its children, so the row is given its height.
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT_PX)
	row.add_child(line)
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = ROW_INSET_LEFT_PX
	line.offset_right = -ROW_INSET_RIGHT_PX
	# A disabled row, such as someone who can't leave, shows everything in it dimmed. A button
	# redraws whenever it is disabled or enabled.
	row.draw.connect(func() -> void: line.modulate = DISABLED_ROW_TINT if row.disabled else Color.WHITE)
	return row


# One compact card per filled slot of `candidates`, in slot order: the candidate's face, name, title
# and rank over their stats, and a hire button; the reason a hire is refused under them. A tap
# anywhere else on the card opens the candidate.
func _build_candidates(candidates: Array[Dictionary]) -> void:
	_candidates_shown = candidates.duplicate()
	for row: Node in _candidates.get_children():
		_candidates.remove_child(row)
		row.queue_free()
	_candidate_cards.clear()
	_hires.clear()
	_hire_reasons.clear()
	for slot: int in candidates.size():
		var candidate := candidates[slot]
		if candidate.is_empty():
			continue
		var who: Dictionary = candidate["who"]
		var hire := _small_button("Hire · %dg" % Recruits.hire_gold(candidate), &"GoldButton")
		hire.pressed.connect(hire_pressed.emit.bind(slot))
		_hires[slot] = hire
		var line := _compact_line(QuestBoard.face_token(who["face_seed"]), who["name"],
				"%s · rank %s" % [Recruits.title(candidate), who["rank"]], Recruits.stats_line(candidate))
		line.add_child(hire)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 16)
		box.add_child(line)
		_hire_reasons[slot] = _label("", &"Alert")
		box.add_child(_hire_reasons[slot])
		var row := PanelContainer.new()
		row.add_child(box)
		_candidate_cards[slot] = row
		_candidates.add_child(_over_tap(row, visitor_pressed.emit.bind(slot)))
	_show_mark()


# The walk-in's compact card under its section label, like a candidate's: their face in their gear,
# name, title, rank and level over their stats, with Turn away and Accept or Swap. A tap anywhere
# else on the card opens the walk-in.
func _build_walk_in(walk_in: Dictionary) -> void:
	_walk_in_shown = walk_in.duplicate()
	# Everything after the section label.
	for card: Node in _walk_in.get_children().slice(1):
		_walk_in.remove_child(card)
		card.queue_free()
	_walk_in_card = null
	_walk_in.visible = not walk_in.is_empty()
	if walk_in.is_empty():
		return
	var who: Dictionary = walk_in["who"]
	var line := _compact_line(QuestBoard.face_token(who["face_seed"], walk_in["worn"]), who["name"],
			"%s · rank %s · level %d" % [Recruits.title(walk_in), who["rank"], walk_in.get("level", 1)], Recruits.stats_line(walk_in))
	var turn_away := _small_button("Turn away", &"OutlineButton")
	turn_away.pressed.connect(turn_away_pressed.emit)
	_accept = _small_button("Accept", &"GoldButton")
	_accept.pressed.connect(accept_pressed.emit)
	_swap = _small_button("Swap", &"GoldButton")
	_swap.pressed.connect(swap_pressed.emit)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	for button: Button in [turn_away, _accept, _swap]:
		buttons.add_child(button)
	line.add_child(buttons)
	_walk_in_card = PanelContainer.new()
	_walk_in_card.add_child(line)
	_walk_in.add_child(_over_tap(_walk_in_card, visitor_pressed.emit.bind(WALK_IN)))
	_show_mark()


# `card` over a see-through button, a tap on which calls `on_tap`: everything on the card but its
# own buttons lets presses through to it.
static func _over_tap(card: Control, on_tap: Callable) -> MarginContainer:
	var tap := Button.new()
	tap.flat = true
	tap.pressed.connect(on_tap)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for part: Node in card.find_children("*", "Control", true, false):
		if not part is BaseButton:
			(part as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A MarginContainer stacks its children, so the button is the card's size, under it.
	var stack := MarginContainer.new()
	stack.add_child(tap)
	stack.add_child(card)
	return stack


# A candidate's or walk-in's row, short of its buttons: `face`, then `name_text` with `details` on
# its line, over `stats`, each line cut short rather than wrapped. Buttons added after them go on
# the same line while it has room, else wrap under it, so the row fits the narrow landscape column.
static func _compact_line(face: Control, name_text: String, details: String, stats: String) -> HFlowContainer:
	var name_label := _label(name_text, &"RowTitle")
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var name_line := HBoxContainer.new()
	name_line.add_theme_constant_override("separation", 16)
	name_line.add_child(name_label)
	name_line.add_child(QuestBoard.one_line(details, &"Caption"))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_child(name_line)
	words.add_child(QuestBoard.one_line(stats, &"Caption"))
	var line := HFlowContainer.new()
	line.alignment = FlowContainer.ALIGNMENT_END
	line.add_theme_constant_override("h_separation", ROW_GAP_PX)
	line.add_theme_constant_override("v_separation", 16)
	line.add_child(face)
	line.add_child(words)
	return line


static func _small_button(text: String, variation: StringName) -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = variation
	button.custom_minimum_size = Vector2(0, SMALL_BUTTON_PX)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override(&"font_size", SMALL_FONT_PX)
	return button


static func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.theme_type_variation = variation
	return label
