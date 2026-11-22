class_name PartyPicker
extends PanelContainer

## The player chose to send `party`, keys of Adventurers.roster, on `quest`.
signal send_pressed(quest: String, party: PackedStringArray)
## The player is done with the quest picked without sending a party.
signal back_pressed

## The tick on a picked adventurer's card.
const TICK_SIZE_PX: float = 40.0
const TICK_GOLD: Color = Color("#f2c14e")
const TICK_MARK: Color = Color("#16131b")
## The most cards in a row, in landscape and in portrait; more wrap to the next.
const CARDS_ACROSS: int = 4
const PORTRAIT_CARDS_ACROSS: int = 2
## How many times larger than its pixels a figure shows on a docked card, so four fit across.
const DOCKED_FIGURE_SCALE: int = 5
## In landscape the gaps between the picker's parts shrink to this, so the docked panel fits
## without scrolling.
const LANDSCAPE_GAP_PX: int = 12

var _quest: String = ""
var _picked: PackedStringArray = PackedStringArray()
## The adventurers the toggles were built for, in roster order, so they are rebuilt only when
## someone joins or leaves.
var _built: Array = []
var _toggles: Dictionary[String, Button] = {}
## Each adventurer's figure for their card: [in portrait, docked].
var _figures: Dictionary[String, Array] = {}
## The tick on each adventurer's card, shown when they are picked.
var _ticks: Dictionary[String, Control] = {}
## The dispatch and time last shown, so picking someone can update the odds at once.
var _dispatch: Dispatch
var _now: int = 0
## The quest's unknown challenges the forecast was last shown with, so a reveal while the picker
## is open shows at once and nothing else rebuilds it.
var _forecast_unknown: PackedStringArray = PackedStringArray()
## Whether the picker sits beside the board rather than being a screen of its own.
var _docked: bool = false
## The picker's stacks and their gaps as the scene has them, for portrait.
var _portrait_gaps: Dictionary[BoxContainer, int] = {}
## The picker's panel as the scene has it, for portrait: none.
var _portrait_panel: StyleBox

@onready var _title: Label = $Root/Scroll/Box/Heading/Title
@onready var _meta: Label = $Root/Scroll/Box/Heading/Meta
@onready var _list: GridContainer = $Root/Scroll/Box/List
@onready var _coverage: HFlowContainer = $Root/Scroll/Box/Forecast/Box/Coverage
@onready var _chance: Control = $Root/Scroll/Box/Forecast/Box/Chance
@onready var _odds: Label = $Root/Scroll/Box/Forecast/Box/Chance/Odds
@onready var _band: Control = $Root/Scroll/Box/Forecast/Box/Band
@onready var _band_fill: Control = $Root/Scroll/Box/Forecast/Box/Band/Fill
@onready var _note: Label = $Root/Scroll/Box/Forecast/Box/Note
@onready var _reason: Label = $Root/Reason
@onready var _send: Button = $Root/Buttons/Send
@onready var _root: BoxContainer = $Root
@onready var _scroll: ScrollContainer = $Root/Scroll
@onready var _back: Button = $Root/Buttons/Cancel
@onready var _prompt: Label = $Prompt


func _ready() -> void:
	_send.pressed.connect(func() -> void: send_pressed.emit(_quest, _picked))
	_back.pressed.connect(back_pressed.emit)
	for stack: BoxContainer in [_root, $Root/Scroll/Box, $Root/Scroll/Box/Forecast/Box]:
		_portrait_gaps[stack] = stack.get_theme_constant(&"separation")
	_portrait_panel = get_theme_stylebox(&"panel")


## Landscape docks the picker beside the board, a panel with the adventurers' cards four across;
## Cancel drops the quest. Portrait makes it a screen of its own, with no panel, cards two across,
## and Back. A card shows the adventurer's figure in their gear, name, title and health, or their
## status when they can't go. Either way the cards and forecast scroll above the reason and buttons.
func set_landscape(landscape: bool) -> void:
	_docked = landscape
	if landscape:
		remove_theme_stylebox_override(&"panel")
	else:
		add_theme_stylebox_override(&"panel", _portrait_panel)
	_back.text = "Cancel" if landscape else "Back"
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER if landscape else ScrollContainer.SCROLL_MODE_AUTO
	_title.theme_type_variation = &"Heading" if landscape else &"Title"
	for stack: BoxContainer in _portrait_gaps:
		stack.add_theme_constant_override(&"separation", LANDSCAPE_GAP_PX if landscape else _portrait_gaps[stack])
	_lay_out_toggles()
	if has_quest():
		show_dispatch(_dispatch, _now)


# The cards as many across as `_docked` says.
func _lay_out_toggles() -> void:
	_list.columns = clampi(_toggles.size(), 1, CARDS_ACROSS if _docked else PORTRAIT_CARDS_ACROSS)
	for adventurer: String in _toggles:
		_toggles[adventurer].icon = _figures[adventurer][1 if _docked else 0]


# One card per adventurer in `adventurers`' roster, with their figure in their gear; those picked
# stay picked.
func _build(adventurers: Adventurers) -> void:
	var roster := adventurers.roster
	_built = roster.keys()
	for toggle: Button in _toggles.values():
		_list.remove_child(toggle)
		toggle.queue_free()
	_toggles.clear()
	_figures.clear()
	_ticks.clear()
	for adventurer: String in roster:
		var face_seed := Faces.seed_of(adventurer, roster[adventurer])
		var worn: Dictionary = adventurers.gear.worn[adventurer]
		_figures[adventurer] = [QuestBoard.figure(face_seed, worn), QuestBoard.figure(face_seed, worn, DOCKED_FIGURE_SCALE)]
		var toggle := Button.new()
		toggle.toggle_mode = true
		toggle.theme_type_variation = &"PickCard"
		toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		toggle.alignment = HORIZONTAL_ALIGNMENT_CENTER
		toggle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		toggle.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		toggle.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		toggle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		toggle.set_pressed_no_signal(adventurer in _picked)
		toggle.toggled.connect(_on_toggled.bind(adventurer))
		_toggles[adventurer] = toggle
		_list.add_child(toggle)
		var tick := Control.new()
		tick.visible = false
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tick.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		tick.position = Vector2(-TICK_SIZE_PX - 12, 12)
		tick.size = Vector2.ONE * TICK_SIZE_PX
		tick.draw.connect(_draw_tick.bind(tick))
		toggle.add_child(tick)
		_ticks[adventurer] = tick
	_lay_out_toggles()


## Whether a quest is picked, so the picker has a party to choose.
func has_quest() -> bool:
	return not _quest.is_empty()


## Drops the quest, so the picker prompts for one.
func close() -> void:
	_quest = ""
	_root.hide()
	_prompt.show()


## Opens the picker for `quest` with nobody picked.
func open(quest: String, dispatch: Dispatch, now: int) -> void:
	_quest = quest
	_prompt.hide()
	_root.show()
	_picked = PackedStringArray()
	for toggle: Button in _toggles.values():
		toggle.set_pressed_no_signal(false)
	var info: Dictionary = Dispatch.QUESTS[quest]
	_title.text = info["name"]
	_meta.text = "Rank %s · %s · %d gold" % [info["rank"], Duration.label(info["seconds"]), info["gold"]]
	_dispatch = dispatch
	_show_forecast()
	show_dispatch(dispatch, now)


## Shows `dispatch` at `now`.
func show_dispatch(dispatch: Dispatch, now: int) -> void:
	_dispatch = dispatch
	_now = now
	var roster := dispatch.adventurers.roster
	if roster.keys() != _built:
		_build(dispatch.adventurers)
	for adventurer: String in _toggles:
		var info: Dictionary = roster[adventurer]
		var toggle := _toggles[adventurer]
		var points := dispatch.health(adventurer, now)
		var most := dispatch.adventurers.max_health(adventurer)
		var can_go := dispatch.can_go(adventurer, now)
		if can_go:
			toggle.text = "%s\n%s\n%d / %d health" % [info["name"], dispatch.adventurers.title(adventurer), points, most]
		else:
			toggle.text = "%s\n%s" % [info["name"], dispatch.status(adventurer, now)]
		toggle.disabled = not can_go
		_ticks[adventurer].visible = toggle.button_pressed
	var reason := dispatch.party_refusal(_quest, _picked, now)
	_reason.text = reason
	_reason.visible = not reason.is_empty()
	_send.disabled = not reason.is_empty()
	if dispatch.unknown_challenges(_quest) != _forecast_unknown:
		_show_forecast()


# Which known challenges the picked party meets and the chance range it is shown; only picking
# someone or a challenge revealed changes them while the picker is open.
func _show_forecast() -> void:
	for old: Node in _coverage.get_children():
		old.queue_free()
	var unknown := _dispatch.unknown_challenges(_quest)
	_forecast_unknown = unknown
	for challenge: String in Dispatch.QUESTS[_quest]["challenges"]:
		if challenge in unknown:
			_coverage.add_child(QuestBoard.chip("? unknown", &"ChipUnknown"))
			continue
		var met := _dispatch.challenge_met(_quest, challenge, _picked)
		_coverage.add_child(QuestBoard.chip(challenge, &"ChipCovered" if met else &"ChipUncovered"))
	var picked := not _picked.is_empty()
	_chance.visible = picked
	_band.visible = picked
	var fail_gold := Dispatch.failure_gold(_quest)
	var note := "If it fails: no gold." if fail_gold == 0 else "If it fails: %d gold." % fail_gold
	if picked:
		var shown := _dispatch.chance_range(_quest, _picked)
		_odds.text = "%d–%d%%" % [shown.x, shown.y]
		_band_fill.anchor_left = shown.x / 100.0
		_band_fill.anchor_right = shown.y / 100.0
		# Every quest starts with at most one challenge unknown.
		if not unknown.is_empty():
			note = "One challenge is still unknown; revealing it narrows the range. " + note
	_note.text = note


# A gold disc with a dark check mark.
func _draw_tick(tick: Control) -> void:
	tick.draw_circle(tick.size / 2.0, TICK_SIZE_PX / 2.0, TICK_GOLD)
	var points := PackedVector2Array([Vector2(0.28, 0.52), Vector2(0.44, 0.68), Vector2(0.74, 0.36)])
	for i: int in points.size():
		points[i] *= TICK_SIZE_PX
	tick.draw_polyline(points, TICK_MARK, TICK_SIZE_PX / 10.0, true)


func _on_toggled(picked: bool, adventurer: String) -> void:
	if picked:
		_picked.append(adventurer)
	else:
		_picked.remove_at(_picked.find(adventurer))
	show_dispatch(_dispatch, _now)
	_show_forecast()
