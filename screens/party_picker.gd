class_name PartyPicker
extends PanelContainer

## The player chose to send `party`, keys of Adventurers.roster, on `quest`.
signal send_pressed(quest: String, party: PackedStringArray)
## The player is done with the quest picked without sending a party.
signal back_pressed
## The quest picked left the board, so the picker dropped it and prompts for one.
signal quest_left

## The check circle at the right of a row: gold with a dark mark when the adventurer is picked, an
## empty ring when not.
const CHECK_SIZE_PX: float = 60.0
const CHECK_RING_PX: float = 4.0
const CHECK_GOLD: Color = Color("#f2c14e")
const CHECK_MARK: Color = Color("#16131b")
const CHECK_RING: Color = Color("#4a4258")
## The space above and below a row's lines once they need more than a roster row's height.
const ROW_PADDING_PX: int = 16

var _quest: String = ""
var _picked: PackedStringArray = PackedStringArray()
## The adventurers the rows were built for, in roster order, so they are rebuilt only when someone
## joins or leaves; and the order they were last shown in, those who can go first, so they move
## only when who can go changes.
var _built: Array = []
var _order: PackedStringArray = PackedStringArray()
## Each adventurer's row and its parts that change: their title, the stats the quest tests, health,
## the check circle and, in its place, why they can't go.
var _rows: Dictionary[String, Button] = {}
var _titles: Dictionary[String, Label] = {}
var _stats: Dictionary[String, Label] = {}
var _healths: Dictionary[String, HBoxContainer] = {}
var _checks: Dictionary[String, Control] = {}
var _reasons: Dictionary[String, Label] = {}
## Each adventurer's level and gear when their title and stats were last shown, so those are shown
## again only when one of them changes.
var _looks_shown: Dictionary[String, Array] = {}
## The pill of each known challenge, coloured by whether the picked party meets it, and the stats
## those challenges test, in the order a row shows them.
var _pills: Dictionary[String, Label] = {}
var _tested: PackedStringArray = PackedStringArray()
## The dispatch and time last shown, so picking someone can update the odds at once.
var _dispatch: Dispatch
var _now: int = 0
## The quest's unknown challenges the pills were last built with, so a reveal while the picker is
## open shows at once and nothing else rebuilds them.
var _forecast_unknown: PackedStringArray = PackedStringArray()

@onready var _title: Label = $Root/Quest/Box/Title
@onready var _meta: Label = $Root/Quest/Box/Meta
@onready var _coverage: HFlowContainer = $Root/Quest/Box/Coverage
@onready var _slots: HBoxContainer = $Root/Quest/Box/Party/Slots
@onready var _odds: Label = $Root/Quest/Box/Party/Chance/Line/Odds
@onready var _band_fill: Control = $Root/Quest/Box/Party/Chance/Band/Fill
@onready var _list: VBoxContainer = $Root/Scroll/List
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


## Landscape docks the picker beside the board, where Cancel drops the quest; portrait makes it a
## screen of its own, with Back. Either way the quest card stays put above the scrolling rows.
func set_landscape(landscape: bool) -> void:
	_back.text = "Cancel" if landscape else "Back"


# One row per adventurer in `adventurers`' roster, a toggle: their face, name and title, the stats
# the quest tests, health, and the check circle; those picked stay picked.
func _build(adventurers: Adventurers) -> void:
	_built = adventurers.roster.keys()
	_order = PackedStringArray()
	for row: Node in _list.get_children():
		_list.remove_child(row)
		row.queue_free()
	_rows.clear()
	_titles.clear()
	_stats.clear()
	_healths.clear()
	_checks.clear()
	_reasons.clear()
	_looks_shown.clear()
	# Whoever left the guild leaves the party.
	var staying := PackedStringArray()
	for adventurer: String in _picked:
		if adventurer in adventurers.roster:
			staying.append(adventurer)
	_picked = staying
	for adventurer: String in adventurers.roster:
		var row := Roster.adventurer_row(adventurer, adventurers)
		row.toggle_mode = true
		row.set_pressed_no_signal(adventurer in _picked)
		row.toggled.connect(_on_toggled.bind(adventurer))
		var health := row.find_child("Health", true, false) as HBoxContainer
		# The bar alone: the row has no room for the numbers.
		(health.get_child(1) as Control).visible = false
		# The stats on a line of their own, between the name and the bar, so the name and title are
		# never cut; they wrap between stats where the row is too narrow for all of them.
		var stats := row.find_child("Status", true, false) as Label
		stats.theme_type_variation = &"MetaSmall"
		stats.remove_theme_font_size_override(&"font_size")
		stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var words := health.get_parent()
		stats.get_parent().remove_child(stats)
		words.add_child(stats)
		words.move_child(stats, health.get_index())
		var check := Control.new()
		check.name = "Check"
		check.custom_minimum_size = Vector2.ONE * CHECK_SIZE_PX
		check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		check.mouse_filter = Control.MOUSE_FILTER_IGNORE
		check.draw.connect(_draw_check.bind(check, row))
		var reason := Label.new()
		reason.theme_type_variation = &"Caption"
		reason.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var line := row.get_child(0) as Control
		line.add_child(check)
		line.add_child(reason)
		# A button does not fit its children, so the row takes the height its lines need with room
		# above and below, at least a roster row's.
		line.minimum_size_changed.connect(func() -> void:
			row.custom_minimum_size.y = maxf(Roster.ROW_HEIGHT_PX, line.get_combined_minimum_size().y + 2 * ROW_PADDING_PX))
		_rows[adventurer] = row
		_titles[adventurer] = row.find_child("Details", true, false)
		_stats[adventurer] = stats
		_healths[adventurer] = health
		_checks[adventurer] = check
		_reasons[adventurer] = reason
		_list.add_child(row)


## Whether a quest is picked, so the picker has a party to choose.
func has_quest() -> bool:
	return not _quest.is_empty()


## Drops the quest, so the picker prompts for one.
func close() -> void:
	_quest = ""
	_root.hide()
	_prompt.show()


## Drops the quest picked once `board` no longer shows it, since it can't be sent.
func show_board(board: Board) -> void:
	if has_quest() and not board.slots.has(_quest):
		close()
		quest_left.emit()


## Opens the picker for `quest` with nobody picked.
func open(quest: String, dispatch: Dispatch, now: int) -> void:
	_quest = quest
	_prompt.hide()
	_root.show()
	_picked = PackedStringArray()
	for adventurer: String in _rows:
		_rows[adventurer].set_pressed_no_signal(false)
		_checks[adventurer].queue_redraw()
	var info: Dictionary = Dispatch.QUESTS[quest]
	_title.text = info["name"]
	_meta.text = "%s · %s · %dg · fail %dg" % [info["rank"], Duration.label(info["seconds"]), info["gold"], Dispatch.failure_gold(quest)]
	_dispatch = dispatch
	_build_pills()
	_show_party()
	show_dispatch(dispatch, now)


## Shows `dispatch` at `now`: everyone who can go on the quest first, in roster order, then everyone
## who can't, dimmed, with the reason in place of the check. The party's slots and forecast change
## only when the roster, a challenge or a picked adventurer's level or gear does.
func show_dispatch(dispatch: Dispatch, now: int) -> void:
	_dispatch = dispatch
	_now = now
	var adventurers := dispatch.adventurers
	var party_changed := false
	if adventurers.roster.keys() != _built:
		_build(adventurers)
		party_changed = true
	if dispatch.unknown_challenges(_quest) != _forecast_unknown:
		_build_pills()
		party_changed = true
	var free := PackedStringArray()
	var held := PackedStringArray()
	for adventurer: String in _rows:
		var reason := _reason_held(adventurer)
		var row := _rows[adventurer]
		row.disabled = not reason.is_empty()
		_reasons[adventurer].text = reason
		_reasons[adventurer].visible = row.disabled
		_checks[adventurer].visible = not row.disabled
		var look := [adventurers.levels[adventurer], adventurers.gear.worn[adventurer]]
		if look != _looks_shown.get(adventurer, []):
			_looks_shown[adventurer] = look.duplicate(true)
			_titles[adventurer].text = adventurers.title(adventurer)
			_stats[adventurer].text = _stats_line(adventurer)
			party_changed = party_changed or adventurer in _picked
		_stats[adventurer].visible = not row.disabled
		Adventurer.show_health(_healths[adventurer], adventurer, dispatch, now)
		(held if row.disabled else free).append(adventurer)
	var order := free + held
	if order != _order:
		_order = order
		for at: int in order.size():
			_list.move_child(_rows[order[at]], at)
	if party_changed:
		_show_party()
	_show_refusal()


# Why `adventurer` can't go on the quest at `_now`, in words for the player; "" when they can.
func _reason_held(adventurer: String) -> String:
	if not _dispatch.can_go(adventurer, _now):
		for outing: Dictionary in _dispatch.outings:
			if adventurer in outing["party"]:
				return "Out · " + Duration.label(_dispatch.seconds_left(outing, _now))
		return _dispatch.status(adventurer, _now)
	if not Challenges.can_join(_dispatch.adventurers.roster[adventurer]["rank"], Dispatch.QUESTS[_quest]["rank"]):
		return "Rank too low"
	return ""


# "Str 9 · Def 19": `adventurer`'s stats, gear included, that the quest's known challenges test.
# The spaces inside a stat and before each dot don't break, so the line wraps only after a dot.
func _stats_line(adventurer: String) -> String:
	var parts := PackedStringArray()
	for stat: String in _tested:
		parts.append("%s %d" % [Adventurer.SHORT_STATS[stat], _dispatch.adventurers.stat_total(adventurer, stat)])
	return " · ".join(parts)


# A pill for each of the quest's challenges, an unknown one dashed "?", and the stats the known
# ones test.
func _build_pills() -> void:
	for old: Node in _coverage.get_children():
		_coverage.remove_child(old)
		old.queue_free()
	_pills.clear()
	_tested = PackedStringArray()
	var unknown := _dispatch.unknown_challenges(_quest)
	_forecast_unknown = unknown
	# The stats the rows show change with the challenges known.
	_looks_shown.clear()
	for challenge: String in Dispatch.QUESTS[_quest]["challenges"]:
		if challenge in unknown:
			_coverage.add_child(QuestBoard.chip("?", &"PillUnknown"))
			continue
		_pills[challenge] = QuestBoard.chip(challenge, &"Pill")
		_coverage.add_child(_pills[challenge])
		for stat: String in Challenges.WEIGHTS[challenge]:
			if stat not in _tested:
				_tested.append(stat)


# What changes when someone is picked or unpicked: the party's slots, which challenges it meets
# and the chance range it is shown.
func _show_party() -> void:
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
	_send.text = "Send %d · %s" % [_picked.size(), _odds.text] if picked else "Send"


# Why the party can't be sent at `_now`, if it can't, which also holds Send.
func _show_refusal() -> void:
	var reason := _dispatch.party_refusal(_quest, _picked, _now)
	_reason.text = reason
	_reason.visible = not reason.is_empty()
	_send.disabled = not reason.is_empty()


# The check circle of `row`: a gold disc with a dark check mark while it is picked, else an empty
# ring.
func _draw_check(check: Control, row: Button) -> void:
	var middle := check.size / 2.0
	if not row.button_pressed:
		check.draw_arc(middle, (CHECK_SIZE_PX - CHECK_RING_PX) / 2.0, 0.0, TAU, 48, CHECK_RING, CHECK_RING_PX, true)
		return
	check.draw_circle(middle, CHECK_SIZE_PX / 2.0, CHECK_GOLD)
	var points := PackedVector2Array([Vector2(0.28, 0.52), Vector2(0.44, 0.68), Vector2(0.74, 0.36)])
	for i: int in points.size():
		points[i] *= CHECK_SIZE_PX
	check.draw_polyline(points, CHECK_MARK, CHECK_SIZE_PX / 10.0, true)


func _on_toggled(picked: bool, adventurer: String) -> void:
	if picked:
		_picked.append(adventurer)
	else:
		_picked.remove_at(_picked.find(adventurer))
	_checks[adventurer].queue_redraw()
	_show_party()
	_show_refusal()
