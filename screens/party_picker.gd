class_name PartyPicker
extends PanelContainer

## The player chose to send `party`, keys of Adventurers.roster, on `quest`.
signal send_pressed(quest: String, party: PackedStringArray)

## The tick on a picked adventurer's card in landscape.
const TICK_SIZE_PX: float = 40.0
const TICK_GOLD: Color = Color("#f2c14e")
const TICK_MARK: Color = Color("#16131b")
## How many times larger than its pixels a face shows on a landscape card, a whole number so the
## pixels stay crisp.
const FACE_SCALE: int = 3
## A face's art in pixels, so a card without one makes the same room for its stand-in.
const FACE_SIZE_PX: Vector2i = Vector2i(20, 18)
## The most landscape cards in a row; more wrap to the next.
const CARDS_ACROSS: int = 4
## A portrait adventurer line's height.
const LINE_HEIGHT_PX: float = 150.0
## In landscape the gaps between the picker's parts shrink to this, so the docked panel fits
## without scrolling.
const LANDSCAPE_GAP_PX: int = 12

var _quest: String = ""
var _picked: PackedStringArray = PackedStringArray()
## The adventurers the toggles were built for, in roster order, so they are rebuilt only when
## someone joins or leaves.
var _built: Array = []
var _toggles: Dictionary[String, Button] = {}
## Each adventurer's face for their landscape card, and the tick shown on it when picked.
var _faces: Dictionary[String, Texture2D] = {}
var _ticks: Dictionary[String, Control] = {}
## The token standing in on the landscape card of each adventurer whose face has no art.
var _stand_ins: Dictionary[String, Label] = {}
## The dispatch and time last shown, so picking someone can update the odds at once.
var _dispatch: Dispatch
var _now: int = 0
## Whether the picker sits beside the board rather than popping up over it.
var _docked: bool = false
## The picker's stacks and their gaps as the scene has them, for portrait.
var _portrait_gaps: Dictionary[BoxContainer, int] = {}

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
@onready var _prompt: Label = $Prompt


func _ready() -> void:
	_send.pressed.connect(func() -> void: send_pressed.emit(_quest, _picked))
	$Root/Buttons/Cancel.pressed.connect(close)
	for stack: BoxContainer in [_root, $Root/Scroll/Box, $Root/Scroll/Box/Forecast/Box]:
		_portrait_gaps[stack] = stack.get_theme_constant(&"separation")
	$Root/Scroll/Box.minimum_size_changed.connect(_fit_scroll)
	_reason.minimum_size_changed.connect(_fit_scroll)
	_reason.visibility_changed.connect(_fit_scroll)


## Landscape docks the picker beside the board, a panel whose adventurers are cards four across:
## face, name, power and health, or their status when they can't go. Portrait pops it up over the
## board, as tall as its content, one adventurer per line, up to the height it is placed at, past
## which the lines and forecast scroll above the reason and buttons.
func set_landscape(landscape: bool) -> void:
	_docked = landscape
	theme_type_variation = &"" if landscape else &"Dialog"
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER if landscape else ScrollContainer.SCROLL_MODE_AUTO
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL if landscape else Control.SIZE_FILL
	_title.theme_type_variation = &"Heading" if landscape else &"Title"
	for stack: BoxContainer in _portrait_gaps:
		stack.add_theme_constant_override(&"separation", LANDSCAPE_GAP_PX if landscape else _portrait_gaps[stack])
	_lay_out_toggles()
	_fit_scroll()
	if has_quest():
		show_dispatch(_dispatch, _now)


# In portrait the scrolled part is as tall as its content while that fits in the height the panel is
# placed at, centred, with the reason and buttons below; taller, it stops there and scrolls, so the
# buttons stay on screen. Docked, it fills whatever the panel leaves.
func _fit_scroll() -> void:
	if _docked:
		_scroll.custom_minimum_size.y = 0.0
		return
	var content := ($Root/Scroll/Box as Control).get_combined_minimum_size().y
	var below := _root.get_combined_minimum_size().y - _scroll.get_combined_minimum_size().y
	var placed := offset_bottom - offset_top - get_theme_stylebox(&"panel").get_minimum_size().y
	_scroll.custom_minimum_size.y = minf(content, placed - below)


# Each adventurer as a landscape card or a portrait line, as `_docked` says.
func _lay_out_toggles() -> void:
	_list.columns = clampi(_toggles.size(), 1, CARDS_ACROSS) if _docked else 1
	for adventurer: String in _toggles:
		var toggle := _toggles[adventurer]
		toggle.theme_type_variation = &"PickCard" if _docked else &""
		toggle.custom_minimum_size.y = 0.0 if _docked else LINE_HEIGHT_PX
		toggle.alignment = HORIZONTAL_ALIGNMENT_CENTER if _docked else HORIZONTAL_ALIGNMENT_LEFT
		toggle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if _docked else TextServer.AUTOWRAP_OFF
		toggle.icon = _faces[adventurer] if _docked else null
		# A top icon makes room for itself even without one, so portrait keeps the defaults.
		toggle.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER if _docked else HORIZONTAL_ALIGNMENT_LEFT
		toggle.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP if _docked else VERTICAL_ALIGNMENT_CENTER
		if adventurer in _stand_ins:
			# Over the blank icon, which the card draws at its top margin.
			_stand_ins[adventurer].visible = _docked
			_stand_ins[adventurer].position.y = toggle.get_theme_stylebox(&"normal").get_margin(SIDE_TOP)


# One toggle per adventurer in `roster`, with their face for the landscape card; those picked
# stay picked.
func _build(roster: Dictionary[String, Dictionary]) -> void:
	_built = roster.keys()
	for toggle: Button in _toggles.values():
		_list.remove_child(toggle)
		toggle.queue_free()
	_toggles.clear()
	_faces.clear()
	_ticks.clear()
	_stand_ins.clear()
	for adventurer: String in roster:
		var toggle := Button.new()
		toggle.toggle_mode = true
		toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		toggle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		toggle.set_pressed_no_signal(adventurer in _picked)
		toggle.toggled.connect(_on_toggled.bind(adventurer))
		_toggles[adventurer] = toggle
		_list.add_child(toggle)
		var art := QuestBoard.face(roster[adventurer])
		if art:
			var face := art.get_image()
			face.resize(face.get_width() * FACE_SCALE, face.get_height() * FACE_SCALE, Image.INTERPOLATE_NEAREST)
			_faces[adventurer] = ImageTexture.create_from_image(face)
		else:
			# No art: their token, with their initial, over a blank icon as large as a face, so the
			# card's text lines up with the others'; the token shrinks to the face's height to fit.
			var room := Vector2(FACE_SIZE_PX * FACE_SCALE)
			var stand_in := QuestBoard.token(adventurer, roster)
			stand_in.custom_minimum_size = Vector2.ONE * room.y
			stand_in.anchor_left = 0.5
			stand_in.anchor_right = 0.5
			stand_in.offset_left = -room.y / 2.0
			stand_in.offset_right = room.y / 2.0
			toggle.add_child(stand_in)
			_stand_ins[adventurer] = stand_in
			_faces[adventurer] = ImageTexture.create_from_image(Image.create_empty(int(room.x), int(room.y), false, Image.FORMAT_RGBA8))
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


## Drops the quest: docked, the picker prompts for one instead; otherwise it hides.
func close() -> void:
	_quest = ""
	_root.hide()
	_prompt.show()
	visible = _docked


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
	show()
	show_dispatch(dispatch, now)
	_show_forecast()


## Shows `dispatch` at `now`.
func show_dispatch(dispatch: Dispatch, now: int) -> void:
	_dispatch = dispatch
	_now = now
	var roster := dispatch.adventurers.roster
	if roster.keys() != _built:
		_build(roster)
	for adventurer: String in _toggles:
		var info: Dictionary = roster[adventurer]
		var toggle := _toggles[adventurer]
		var points := dispatch.health(adventurer, now)
		var most := dispatch.adventurers.max_health(adventurer)
		var power := dispatch.adventurers.power(adventurer)
		var can_go := dispatch.can_go(adventurer, now)
		if not _docked:
			toggle.text = "%s · %s %s · power %d\n%s · health %d / %d" % [info["name"], info["class"], info["rank"], power, dispatch.status(adventurer, now), points, most]
		elif can_go:
			toggle.text = "%s\nPower %d\n%d / %d health" % [info["name"], power, points, most]
		else:
			toggle.text = "%s\n%s" % [info["name"], dispatch.status(adventurer, now)]
		toggle.disabled = not can_go
		_ticks[adventurer].visible = _docked and toggle.button_pressed
	var reason := dispatch.party_refusal(_quest, _picked, now)
	_reason.text = reason
	_reason.visible = not reason.is_empty()
	_send.disabled = not reason.is_empty()


# Which challenges the picked party covers and the chance range it is shown; only picking
# someone changes them while the picker is open.
func _show_forecast() -> void:
	for old: Node in _coverage.get_children():
		old.queue_free()
	var unknown := _dispatch.unknown_challenges(_quest)
	for challenge: String in Dispatch.QUESTS[_quest]["challenges"]:
		if challenge in unknown:
			_coverage.add_child(QuestBoard.chip("? unknown", &"ChipUnknown"))
			continue
		var names := PackedStringArray()
		var roster := _dispatch.adventurers.roster
		for adventurer: String in Challenges.covered_by(challenge, _picked, roster):
			names.append(roster[adventurer]["name"])
		if names.is_empty():
			_coverage.add_child(QuestBoard.chip(challenge, &"ChipUncovered"))
		else:
			_coverage.add_child(QuestBoard.chip("%s · %s" % [challenge, ", ".join(names)], &"ChipCovered"))
	var picked := not _picked.is_empty()
	_chance.visible = picked
	_band.visible = picked
	var note := "If it fails: %d gold." % Dispatch.failure_gold(_quest)
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
