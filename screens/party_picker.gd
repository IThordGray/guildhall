class_name PartyPicker
extends PanelContainer

## The player chose to send `party`, keys of Adventurers.roster, on `quest`: one party's members.
signal send_pressed(quest: String, party: PackedStringArray)
## The player is done with the quest picked without sending a party.
signal back_pressed
## The quest picked left the board, so the picker dropped it and prompts for one.
signal quest_left

## The space above and below a row's lines.
const ROW_PADDING_PX: int = 16

var _quest: String = ""
## The id of the party picked (Parties), "" for none, and its members, whom Send sends.
var _picked_party: String = ""
var _picked: PackedStringArray = PackedStringArray()
## The rows' toggles, so picking one party unpicks the one picked before; a tap on the one picked
## unpicks it.
var _toggles: ButtonGroup
## Each party's id and members the rows were built for, so they are rebuilt only when a party is
## made, goes or changes members; and the order they were last shown in, those who can go first,
## so they move only when who can go changes.
var _built: Array = []
var _order: PackedStringArray = PackedStringArray()
## Each party's row, by its id, and its parts that change: its name, rank, the chance range it
## would have and, in its place, why it can't go.
var _rows: Dictionary[String, Button] = {}
var _names: Dictionary[String, Label] = {}
var _ranks: Dictionary[String, Label] = {}
var _ranges: Dictionary[String, Label] = {}
var _reasons: Dictionary[String, Label] = {}
## What each party's rank and range were last shown from: its members' ranks, levels and gear and
## the guild's tries at the quest, so they are worked out again only when one of those changes.
var _looks_shown: Dictionary[String, Array] = {}
## The pill of each known challenge, coloured by whether the picked party meets it.
var _pills: Dictionary[String, Label] = {}
## The dispatch and time last shown, so picking a party can update the odds at once.
var _dispatch: Dispatch
var _now: int = 0
## The quest's unknown challenges the pills were last built with, so a reveal while the picker is
## open shows at once and nothing else rebuilds them.
var _forecast_unknown: PackedStringArray = PackedStringArray()
## The Story tag beside a story quest's name.
var _story_tag: Label

@onready var _heading: HBoxContainer = $Root/Quest/Box/Heading
@onready var _title: Label = $Root/Quest/Box/Heading/Title
@onready var _meta: Label = $Root/Quest/Box/Meta
## Under the meta line of a story quest, which stays until done.
@onready var _story_line: Label = $Root/Quest/Box/StoryLine
@onready var _coverage: HFlowContainer = $Root/Quest/Box/Coverage
@onready var _slots: HBoxContainer = $Root/Quest/Box/Party/Slots
@onready var _odds: Label = $Root/Quest/Box/Party/Chance/Line/Odds
@onready var _band_fill: Control = $Root/Quest/Box/Party/Chance/Band/Fill
@onready var _list: VBoxContainer = $Root/Scroll/Box/List
## The quiet line under the list saying how many in reserve can't go, while anyone is.
@onready var _reserves: Label = $Root/Scroll/Box/Reserves
@onready var _reason: Label = $Root/Reason
@onready var _send: Button = $Root/Buttons/Send
@onready var _root: BoxContainer = $Root
@onready var _back: Button = $Root/Buttons/Cancel
@onready var _prompt: Label = $Prompt


func _ready() -> void:
	_send.pressed.connect(func() -> void: send_pressed.emit(_quest, _picked))
	_back.pressed.connect(back_pressed.emit)
	_list.draw.connect(QuestBoard.draw_card.bind(_list))
	# Rows moving inside the list move the lines between them.
	_list.sort_children.connect(_list.queue_redraw)
	_story_tag = QuestBoard.story_tag(self)
	_heading.add_child(_story_tag)


## Landscape docks the picker beside the board, where Cancel drops the quest; portrait makes it a
## screen of its own, with Back. Either way the quest card stays put above the scrolling rows.
func set_landscape(landscape: bool) -> void:
	_back.text = "Cancel" if landscape else "Back"


# One row per party of `adventurers`, a tap on which picks it; the party picked stays picked while
# it lasts.
func _build(adventurers: Adventurers) -> void:
	_built = adventurers.parties.groups()
	_order = PackedStringArray()
	for row: Node in _list.get_children():
		_list.remove_child(row)
		row.queue_free()
	for parts: Dictionary in [_rows, _names, _ranks, _ranges, _reasons, _looks_shown]:
		parts.clear()
	if adventurers.parties.party(_picked_party).is_empty():
		_picked_party = ""
	_toggles = ButtonGroup.new()
	_toggles.allow_unpress = true
	for party: Dictionary in adventurers.parties.parties:
		_list.add_child(_party_row(party["id"], party["members"], adventurers.roster))
	_show_picked()


# The row of party `id` of `members` in `roster`: its rank pill and name over its members' faces,
# and at the right the chance range it would have, or why it can't go.
func _party_row(id: String, members: PackedStringArray, roster: Dictionary) -> Button:
	var party_name := QuestBoard.one_line("", &"RowTitle")
	var rank := QuestBoard.chip("", &"Pill")
	rank.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 16)
	# The pill first, so it lines up from row to row whatever is at their right.
	top.add_child(rank)
	top.add_child(party_name)
	var faces := HBoxContainer.new()
	faces.theme_type_variation = &"TokenStack"
	faces.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for adventurer: String in members:
		faces.add_child(QuestBoard.token(adventurer, roster))
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_child(top)
	words.add_child(faces)
	var shown_range := Label.new()
	shown_range.theme_type_variation = &"GoldText"
	shown_range.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var reason := Label.new()
	reason.theme_type_variation = &"Caption"
	reason.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", Roster.ROW_GAP_PX)
	line.add_child(words)
	line.add_child(shown_range)
	line.add_child(reason)
	var row := Button.new()
	row.theme_type_variation = &"ListRow"
	row.toggle_mode = true
	row.button_group = _toggles
	row.add_child(line)
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = Roster.ROW_INSET_LEFT_PX
	line.offset_right = -Roster.ROW_INSET_RIGHT_PX
	# A button does not fit its children, so the row takes the height its lines need with room
	# above and below, at least a roster row's.
	line.minimum_size_changed.connect(func() -> void:
		row.custom_minimum_size.y = maxf(Roster.ROW_HEIGHT_PX, line.get_combined_minimum_size().y + 2 * ROW_PADDING_PX))
	# A party that can't go shows everything in its row dimmed. A button redraws whenever it is
	# disabled or enabled.
	row.draw.connect(func() -> void: line.modulate = Roster.DISABLED_ROW_TINT if row.disabled else Color.WHITE)
	row.toggled.connect(_on_toggled)
	_rows[id] = row
	_names[id] = party_name
	_ranks[id] = rank
	_ranges[id] = shown_range
	_reasons[id] = reason
	return row


## Whether a quest is picked, so the picker has a party to choose.
func has_quest() -> bool:
	return not _quest.is_empty()


## Drops the quest, so the picker prompts for one.
func close() -> void:
	_quest = ""
	_root.hide()
	_prompt.show()


## Drops the quest picked once neither `board` shows it nor it is among the open story quests in
## `story` (Dispatch.open_story_quests), since it can't be sent.
func show_board(board: Board, story: PackedStringArray = PackedStringArray()) -> void:
	if has_quest() and not board.slots.has(_quest) and not story.has(_quest):
		close()
		quest_left.emit()


## Opens the picker for `quest` with no party picked; a story quest with its Story tag and a line
## saying it stays until done.
func open(quest: String, dispatch: Dispatch, now: int) -> void:
	_quest = quest
	_prompt.hide()
	_root.show()
	_picked_party = ""
	_show_picked()
	var info: Dictionary = Dispatch.QUESTS[quest]
	_title.text = info["name"]
	_meta.text = "%s · %s · %dg · fail %dg" % [info["rank"], Duration.label(info["seconds"]), info["gold"], Dispatch.failure_gold(quest)]
	_story_tag.visible = Dispatch.is_story(quest)
	_story_line.visible = _story_tag.visible
	_dispatch = dispatch
	# Every row's range is the new quest's.
	_looks_shown.clear()
	_build_pills()
	_show_party()
	show_dispatch(dispatch, now)


## Shows `dispatch` at `now`: every party that can go on the quest first, in the order the parties
## were made, then every one that can't, dimmed, with the reason in place of its range; under them
## how many in reserve can't go. The party's slots and forecast change only when the parties, a
## challenge or a picked member's level or gear does.
func show_dispatch(dispatch: Dispatch, now: int) -> void:
	_dispatch = dispatch
	_now = now
	var adventurers := dispatch.adventurers
	var parties := adventurers.parties
	var party_changed := false
	if parties.groups() != _built:
		_build(adventurers)
		party_changed = true
	if dispatch.unknown_challenges(_quest) != _forecast_unknown:
		_build_pills()
		party_changed = true
	var free := PackedStringArray()
	var held := PackedStringArray()
	for id: String in _rows:
		var party := parties.party(id)
		var members: PackedStringArray = party["members"]
		var reason := _reason_held(members)
		var row := _rows[id]
		row.disabled = not reason.is_empty()
		_reasons[id].text = reason
		_reasons[id].visible = row.disabled
		_ranges[id].visible = not row.disabled
		_names[id].text = party["name"]
		var look := [dispatch.try_points(_quest)]
		for adventurer: String in members:
			look.append_array([adventurers.roster[adventurer]["rank"], adventurers.levels[adventurer], adventurers.gear.worn[adventurer]])
		if look != _looks_shown.get(id, []):
			_looks_shown[id] = look.duplicate(true)
			_ranks[id].text = parties.rank(id, adventurers.roster)
			var shown := dispatch.chance_range(_quest, members)
			_ranges[id].text = "%d–%d%%" % [shown.x, shown.y]
			party_changed = party_changed or id == _picked_party
		(held if row.disabled else free).append(id)
	var order := free + held
	if order != _order:
		_order = order
		for at: int in order.size():
			_list.move_child(_rows[order[at]], at)
	var reserves := parties.reserves(adventurers.roster).size()
	_reserves.text = "%d in reserve can't go: not in a party" % reserves
	_reserves.visible = reserves > 0
	if party_changed:
		_show_party()
	_show_refusal()


# Why the party of `members` can't go on the quest at `_now`, in words for the player; "" when it
# can: while out, the time until it is back; else the first member who can't go and why; else the
# dispatch's refusal, such as its rank.
func _reason_held(members: PackedStringArray) -> String:
	for adventurer: String in members:
		if _dispatch.can_go(adventurer, _now):
			continue
		for outing: Dictionary in _dispatch.outings:
			if adventurer in outing["party"]:
				return "Out · " + Duration.label(_dispatch.seconds_left(outing, _now))
		return "%s · %s" % [_dispatch.adventurers.roster[adventurer]["name"], _dispatch.status(adventurer, _now)]
	return _dispatch.party_refusal(_quest, members, _now)


# A pill for each of the quest's challenges, an unknown one dashed "?".
func _build_pills() -> void:
	for old: Node in _coverage.get_children():
		_coverage.remove_child(old)
		old.queue_free()
	_pills.clear()
	var unknown := _dispatch.unknown_challenges(_quest)
	_forecast_unknown = unknown
	# The ranges count only the challenges known.
	_looks_shown.clear()
	for challenge: String in Dispatch.QUESTS[_quest]["challenges"]:
		if challenge in unknown:
			_coverage.add_child(QuestBoard.chip("?", &"PillUnknown"))
			continue
		_pills[challenge] = QuestBoard.chip(challenge, &"Pill")
		_coverage.add_child(_pills[challenge])


# What changes when a party is picked: its members in the slots, which challenges it meets and the
# chance range it is shown.
func _show_party() -> void:
	_picked = PackedStringArray()
	if not _picked_party.is_empty():
		_picked = _dispatch.adventurers.parties.party(_picked_party)["members"].duplicate()
	for old: Node in _slots.get_children():
		_slots.remove_child(old)
		old.queue_free()
	for at: int in Dispatch.MAX_PARTY_SIZE:
		if at < _picked.size():
			_slots.add_child(QuestBoard.token(_picked[at], _dispatch.adventurers.roster))
		else:
			var empty := QuestBoard.chip("", &"PillUnknown")
			empty.custom_minimum_size = Vector2(80, 80)
			empty.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_slots.add_child(empty)
	for challenge: String in _pills:
		_pills[challenge].theme_type_variation = &"PillCovered" if _dispatch.challenge_met(_quest, challenge, _picked) else &"PillUncovered"
	var picked := not _picked.is_empty()
	_band_fill.visible = picked
	_odds.text = "–"
	if picked:
		var shown := _dispatch.chance_range(_quest, _picked)
		_odds.text = "%d–%d%%" % [shown.x, shown.y]
		_band_fill.anchor_left = shown.x / 100.0
		_band_fill.anchor_right = shown.y / 100.0
	_send.text = "Send · " + _odds.text if picked else "Send"


# Why the party picked can't be sent at `_now`, if it can't, which also holds Send.
func _show_refusal() -> void:
	var reason := _dispatch.party_refusal(_quest, _picked, _now)
	_reason.text = reason
	_reason.visible = not reason.is_empty()
	_send.disabled = not reason.is_empty()


# Marks the row of the party picked, and only it.
func _show_picked() -> void:
	for id: String in _rows:
		_rows[id].set_pressed_no_signal(id == _picked_party)
		_rows[id].theme_type_variation = &"ListRowChosen" if id == _picked_party else &"ListRow"


# Picking a party unpicks the one before, whose row is told while the new one is already pressed,
# so the party picked is whichever row is pressed.
func _on_toggled(_picked_now: bool) -> void:
	_picked_party = ""
	for id: String in _rows:
		if _rows[id].button_pressed:
			_picked_party = id
	_show_picked()
	_show_party()
	_show_refusal()
