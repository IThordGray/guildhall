class_name QuestBoard
extends Control

## The player asked to send a party on `quest`, a key of Dispatch.QUESTS.
signal send_pressed(quest: String)
## The player chose to sell `stash_item`, an item id in the stash, to make room for the loot waiting
## at `index` in Dispatch.waiting_loot.
signal swap_pressed(index: int, stash_item: String)
## The player chose to let the loot waiting at `index` in Dispatch.waiting_loot go.
signal let_go_pressed(index: int)
## The player asked to level up `adventurer`, the first with a level-up ready.
signal level_up_pressed(adventurer: String)
## The player saw the death at `index` in Dispatch.fallen.
signal fallen_seen(index: int)
## The player turned Auto on or off for the party with `party`, its id (Parties).
signal auto_toggled(party: String, on: bool)
## The player asked to switch the Auto mode of the party with `party` between Safe and Bold.
signal mode_toggled(party: String)
## The player turned Elite on or off for the party with `party`: whether Auto may send it on an
## elite expedition (Parties.elite_auto).
signal elite_toggled(party: String, on: bool)

## The length of each dash in an unknown challenge's chip border.
const DASH_LENGTH: float = 12.0
## How many times larger than its pixels a face shows: a whole number, so the pixels stay crisp.
const FACE_SCALE: int = 3
## How many times larger than its pixels a figure shows: the design's 80 × 108 on its 390-wide
## phone, on the 1080-wide screen, to a whole number.
const FIGURE_SCALE: int = 7
## How tall a party row's progress bar is: the design's 4 dp.
const PARTY_BAR_PX: int = 11
## The Auto switch's size, and how far its knob sits inside its track.
const SWITCH_SIZE_PX: Vector2 = Vector2(100, 56)
## The smaller Elite switch's size.
const ELITE_SWITCH_SIZE_PX: Vector2 = Vector2(76, 42)
const KNOB_INSET_PX: float = 7.0
## In portrait, how wide the column of the Auto switch and what is under it is, so the faces line up
## from row to row whether it reads Auto or the mode.
const AUTO_COLUMN_PX: float = 150.0
## The space between a row's faces or icon, its words and what is on its right.
const ROW_GAP_PX: int = 28
## How strongly the Story tag's border shows its gold.
const STORY_BORDER_ALPHA: float = 0.55

## What each adventurer wears, Gear.worn itself, so a token shows it; main sets it when a game opens.
static var worn: Dictionary[String, Dictionary] = {}
## Each person's look shown so far, by their face seed: one per adventurer or candidate shown.
static var _looks: Dictionary[int, Look] = {}

var _rows: Dictionary[String, Control] = {}
## Each story quest's row in the Story band, by its id, and its parts that change.
var _story_rows: Dictionary[String, StoryRow] = {}
## Each quest's meta line followed by its challenge pills, and how many of them were unknown when
## last shown, so the pills change only when a return or the Map room reveals one.
var _chips: Dictionary[String, HFlowContainer] = {}
var _unknown_shown: Dictionary[String, int] = {}
## Each quest's rank, time and gold line, which ends with its time left on the board ("leaves m:ss",
## in landscape the time alone), so it changes each second without rebuilding the row. It is the
## first of the quest's `_chips`.
var _meta: Dictionary[String, Label] = {}
## The board's slots shown, so the rows change only when the board does.
var _shown: PackedStringArray = PackedStringArray()
## What the Needs you rows were built from: the loot waiting, the deaths not yet seen, who has a
## level-up ready, the decision open and, while one is, the stash. They are rebuilt only when one of
## those changes.
var _needs_you_shown: Array = []
## The loot waiting as last shown, and where in it the loot whose decision is open is; -1 for none.
var _loot_shown: Array[Dictionary] = []
var _deciding: int = -1
## The dispatch last shown, so opening or closing a decision shows at once; and the board and time
## last shown with it, so turning the window shows each row's time left in the new layout at once.
var _dispatch: Dispatch
var _board: Board
var _now: int = 0
## The open story quests last shown.
var _story: PackedStringArray = PackedStringArray()
## Whether the guild has unlocked Auto (Goals.AUTO), as last shown: until it has, no party row shows
## its Auto switch or mode, and a party saved with Auto on shows as home.
var _auto_unlocked: bool = true
## Whether the guild has reached rank C, as last shown: until it has, with Auto unlocked, no party
## row shows its Elite switch.
var _rank_c: bool = false
## The parties the Parties rows were built for (Parties.groups), so they are rebuilt only when a
## party is made, goes or changes members; and each row's parts that change, by the party's id.
var _parties_shown: Array = []
var _party_rows: Dictionary[String, PartyRow] = {}
## Whether the window is wider than tall, which moves each party row's faces and Auto onto a line of
## their own, so the narrow board column keeps room for the name and where the party is.
var _landscape: bool = false

@onready var _needs_you_header: Control = $Scroll/Box/NeedsYouHeader
@onready var _needs_you_count: Label = $Scroll/Box/NeedsYouHeader/Count
@onready var _done: Button = $Scroll/Box/NeedsYouHeader/Done
@onready var _needs_you: VBoxContainer = $Scroll/Box/NeedsYou
@onready var _parties_section: Control = $Scroll/Box/PartiesSection
@onready var _party_list: VBoxContainer = $Scroll/Box/PartyList
@onready var _list: VBoxContainer = $Scroll/Box/List
@onready var _story_section: Control = $Scroll/Box/StorySection
@onready var _story_list: VBoxContainer = $Scroll/Box/StoryList
## The one line for the empty slots, beside the board's section label: the soonest refill.
@onready var _refill: Label = $Scroll/Box/BoardHeader/Refill
@onready var _parties: Control = $Scroll/Box/Header/Parties
@onready var _parties_count: Label = $Scroll/Box/Header/Parties/Count


## A party row's parts that change: its name and rank, where it is in its cycle, and its Auto; and
## the parts that move with the orientation, and the places they move between.
class PartyRow extends RefCounted:
	var faces: Control
	var right: BoxContainer
	var top: HBoxContainer
	var middle: HBoxContainer
	var line: HBoxContainer
	var name: Label
	var rank: Label
	var status: Label
	var bar: ProgressBar
	var time: Label
	var auto: Button
	## Under the switch: "Auto" while it is off; the Safe/Bold toggle while it is on.
	var off: Label
	var mode: Button
	## After them, the Elite switch and its label.
	var elite: Button
	var elite_label: Label


## A story quest's row: the whole row, and what shows while it is home or while a party is out on
## it: Send and its meta and challenges, or the party with a bar and the time left.
class StoryRow extends RefCounted:
	var row: Control
	var send: Label
	var out: HBoxContainer
	var party: Label
	var bar: ProgressBar
	var time: Label


## Someone's figure and face as they look in `items`, what they wore when the textures were drawn.
## A change of items redraws the same textures, so every token and figure showing them changes at
## once.
class Look extends RefCounted:
	var items: Dictionary = {}
	## The figure at its own size, and as shown, by how many times larger.
	var figure: Image
	var figures: Dictionary[int, ImageTexture] = {}
	var face: ImageTexture = ImageTexture.new()


func _ready() -> void:
	for list: VBoxContainer in [_needs_you, _party_list, _story_list, _list]:
		list.draw.connect(draw_card.bind(list))
		# Rows moving inside the list move the lines between them.
		list.sort_children.connect(list.queue_redraw)
	for quest: String in Dispatch.QUESTS:
		_meta[quest] = _label("", &"MetaSmall")
		_meta[quest].name = "Meta"
		_meta[quest].autowrap_mode = TextServer.AUTOWRAP_OFF
		_meta[quest].vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# The pills follow the meta line, and go under it where the row is too narrow for them.
		var chips := HFlowContainer.new()
		chips.theme_type_variation = &"Chips"
		chips.add_child(_meta[quest])
		_chips[quest] = chips
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if Dispatch.is_story(quest):
			_story_rows[quest] = _story_row(quest, words)
			_story_list.add_child(_story_rows[quest].row)
			continue
		var title := one_line(Dispatch.QUESTS[quest]["name"], &"RowTitle")
		if Dispatch.is_labyrinth(quest):
			var top := HBoxContainer.new()
			top.add_theme_constant_override("separation", 16)
			top.add_child(title)
			top.add_child(labyrinth_tag())
			words.add_child(top)
		else:
			words.add_child(title)
		words.add_child(chips)
		var more := _label("›", &"Secondary")
		more.autowrap_mode = TextServer.AUTOWRAP_OFF
		more.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", ROW_GAP_PX)
		line.add_child(words)
		line.add_child(more)
		var row := PanelContainer.new()
		row.theme_type_variation = &"CardRow"
		row.add_child(line)
		_rows[quest] = _tap_row(row, send_pressed.emit.bind(quest))
		_rows[quest].visible = false
		_list.add_child(_rows[quest])
	_done.pressed.connect(_decide.bind(-1))


## Landscape shows how many parties are out beside the title, puts each party row's faces and Auto
## on a line under its name, and gives each board row's time left without "leaves".
func set_landscape(landscape: bool) -> void:
	_parties.visible = landscape
	_landscape = landscape
	for id: String in _party_rows:
		_place_parts(_party_rows[id])
	if _board != null:
		show_board(_board, _dispatch, _now, _auto_unlocked, _story, _rank_c)


## Shows what needs the player in `dispatch` (deaths not yet seen, loot that found the stash full,
## and level-ups ready) and every party with where it is at `now` and its Auto, then the open story
## quests in `story` (Dispatch.open_story_quests) in a Story band, hidden with none, then the quests
## in `board`'s slots in order, each with the time until it leaves the board, and beside the board's
## label, while a slot is empty, the soonest refill. An unknown challenge shows the time to its reveal
## while the Map room is revealing it. Each party's Auto shows only once the guild has
## `auto_unlocked` it, and its Elite only once the guild has also reached `rank_c`.
func show_board(board: Board, dispatch: Dispatch, now: int, auto_unlocked: bool = true, story: PackedStringArray = PackedStringArray(), rank_c: bool = false) -> void:
	_dispatch = dispatch
	_board = board
	_now = now
	_auto_unlocked = auto_unlocked
	_rank_c = rank_c
	_story = story
	_parties_count.text = str(dispatch.outings.size())
	_show_needs_you(dispatch)
	_show_parties(dispatch, now)
	_show_challenges(dispatch)
	_story_section.visible = not story.is_empty()
	_story_list.visible = _story_section.visible
	for quest: String in _story_rows:
		_story_rows[quest].row.visible = quest in story
		if quest in story:
			_show_story(quest, dispatch, now)
	if board.slots != _shown:
		_shown = board.slots.duplicate()
		for quest: String in _rows:
			_rows[quest].visible = quest in _shown
		# The quests first, in slot order, before the hidden rows.
		var at := 0
		for quest: String in _shown:
			if quest != "":
				_list.move_child(_rows[quest], at)
				at += 1
		_list.visible = at > 0
	var left := board.seconds_to_next_refill(dispatch, now)
	_refill.visible = left >= 0
	_refill.text = "new quest in " + Duration.label(left) if left > 0 else "new quest when one is free"
	for quest: String in _shown:
		if quest == "":
			continue
		var info: Dictionary = Dispatch.QUESTS[quest]
		# The narrow landscape column has room for the time left alone.
		var leaves := Duration.label(board.seconds_to_leave(quest, dispatch, now))
		_meta[quest].text = "%s · %s · %dg · %s" % [info["rank"], Duration.label(info["seconds"]), info["gold"], leaves if _landscape else "leaves " + leaves]
		var reveal := board.seconds_to_reveal(quest, dispatch, now)
		for chip_shown: Label in _chips[quest].get_children():
			if chip_shown.theme_type_variation == &"PillUnknown":
				chip_shown.text = "? · " + Duration.label(reveal) if reveal > 0 else "?"


# The row of story quest `quest` with `words`, which holds nothing yet: its name and Story tag over
# its meta line and challenges, `_chips`, or the party out on it; Send at its right. A tap anywhere
# on it asks to send a party, as a board row does.
func _story_row(quest: String, words: VBoxContainer) -> StoryRow:
	var parts := StoryRow.new()
	var title := _label(Dispatch.QUESTS[quest]["name"], &"RowTitle")
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	top.add_child(title)
	top.add_child(story_tag(self))
	top.add_child(gap)
	parts.party = one_line("", &"Caption")
	parts.party.size_flags_stretch_ratio = 2.0
	parts.bar = ProgressBar.new()
	parts.bar.theme_type_variation = &"GoldBar"
	parts.bar.show_percentage = false
	parts.bar.step = 1.0
	parts.bar.custom_minimum_size = Vector2(0, PARTY_BAR_PX)
	parts.bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parts.bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parts.time = _label("", &"Numbers")
	parts.time.autowrap_mode = TextServer.AUTOWRAP_OFF
	parts.time.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parts.out = HBoxContainer.new()
	parts.out.add_theme_constant_override("separation", 16)
	parts.out.add_child(parts.party)
	parts.out.add_child(parts.bar)
	parts.out.add_child(parts.time)
	words.add_child(top)
	words.add_child(_chips[quest])
	words.add_child(parts.out)
	parts.send = _label("Send ›", &"GoldText")
	parts.send.autowrap_mode = TextServer.AUTOWRAP_OFF
	parts.send.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", ROW_GAP_PX)
	line.add_child(words)
	line.add_child(parts.send)
	var row := PanelContainer.new()
	row.theme_type_variation = &"CardRow"
	row.add_child(line)
	parts.row = _tap_row(row, send_pressed.emit.bind(quest))
	return parts


# Shows story quest `quest`'s row at `now`: while home, Send and its meta line, which says it stays
# until done; while a party is out on it, that party with a bar and the time left, as its party row
# shows it.
func _show_story(quest: String, dispatch: Dispatch, now: int) -> void:
	var parts := _story_rows[quest]
	var outing := {}
	for each: Dictionary in dispatch.outings:
		if each["quest"] == quest:
			outing = each
	parts.out.visible = not outing.is_empty()
	parts.send.visible = outing.is_empty()
	_chips[quest].visible = outing.is_empty()
	if outing.is_empty():
		var info: Dictionary = Dispatch.QUESTS[quest]
		_meta[quest].text = "%s · %s · %dg · stays until done" % [info["rank"], Duration.label(info["seconds"]), info["gold"]]
		return
	parts.party.text = dispatch.adventurers.parties.party(outing.get("party_id", "")).get("name", "")
	var from: int = outing["since"]
	var to := dispatch.back_at(outing)
	var left := dispatch.seconds_left(outing, now)
	parts.bar.max_value = to - from
	parts.bar.value = to - from - left
	parts.time.text = Duration.label(left)


## A gold-outlined "Story" tag, from `themed`'s theme: a Pill with a gold border and words.
static func story_tag(themed: Control) -> Label:
	# The Pill's outline, which it takes from Chip: a lookup by type doesn't follow a variation's base.
	var style := (themed.get_theme_stylebox(&"normal", &"Chip") as StyleBoxFlat).duplicate() as StyleBoxFlat
	var gold := themed.get_theme_color(&"font_color", &"GoldText")
	style.border_color = Color(gold, STORY_BORDER_ALPHA)
	var tag := chip("Story", &"Pill")
	tag.add_theme_stylebox_override(&"normal", style)
	tag.add_theme_color_override(&"font_color", gold)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return tag


## The "Labyrinth" tag after the name of a quest set in the labyrinth (Dispatch.is_labyrinth).
static func labyrinth_tag() -> Label:
	var tag := chip("Labyrinth", &"PillCovered")
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return tag


## A round token: the face of `who` in what they wear when they are in `roster`
## (Adventurers.roster), else `who` as text, such as a count.
static func token(who: String, roster: Dictionary) -> Label:
	if who in roster:
		return face_token(Faces.seed_of(who, roster[who]), worn.get(who, {}))
	return _token(who)


## A round token showing the face made from `face_seed` wearing `items`, such as a candidate's,
## who wears nothing, before they are hired.
static func face_token(face_seed: int, items: Dictionary = {}) -> Label:
	var label := _token("")
	# The face at FACE_SCALE, a whole number, so its pixels stay crisp, centred in the circle.
	var picture := TextureRect.new()
	picture.texture = face(face_seed, items)
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.position = Vector2(10, 13)
	label.add_child(picture)
	return label


# A round token with `text` in it.
static func _token(text: String) -> Label:
	var label := _label(text, &"Token")
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.custom_minimum_size = Vector2(80, 80)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return label


## The face made from `face_seed` wearing `items`, FACE_SCALE times its pixels.
static func face(face_seed: int, items: Dictionary = {}) -> Texture2D:
	return _look(face_seed, items).face


## The figure made from `face_seed` wearing `items`, `scale` times its pixels: a whole number, so
## the pixels stay crisp.
static func figure(face_seed: int, items: Dictionary, scale: int = FIGURE_SCALE) -> Texture2D:
	var look := _look(face_seed, items)
	if scale not in look.figures:
		look.figures[scale] = ImageTexture.create_from_image(_scaled(look.figure, scale))
	return look.figures[scale]


# The look of whoever has `face_seed`, wearing `items`. It is drawn only when first shown and when
# what they wear changes, and only their latest look is kept, so no more are kept than the guild
# has had adventurers and candidates.
static func _look(face_seed: int, items: Dictionary) -> Look:
	var look: Look = _looks.get(face_seed)
	if look != null and look.items == items:
		return look
	if look == null:
		look = Look.new()
		_looks[face_seed] = look
	look.items = items.duplicate()
	look.figure = Figures.image(face_seed, items)
	for scale: int in look.figures:
		look.figures[scale].set_image(_scaled(look.figure, scale))
	look.face.set_image(_scaled(Faces.image(face_seed, items), FACE_SCALE))
	return look


# A copy of `image`, `scale` times larger, its pixels kept square and sharp.
static func _scaled(image: Image, scale: int) -> Image:
	var larger := image.duplicate() as Image
	larger.resize(image.get_width() * scale, image.get_height() * scale, Image.INTERPOLATE_NEAREST)
	return larger


## A challenge chip in `variation`: Chip, ChipCovered, ChipUncovered or ChipUnknown, the last with
## a dashed border; or the board's smaller Pill and PillUnknown, the last dashed.
static func chip(text: String, variation: StringName) -> Label:
	var label := _label(text, variation)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	if variation in [&"ChipUnknown", &"PillUnknown"]:
		label.draw.connect(func() -> void: _draw_dashed_border(label))
	return label


# A StyleBox can't draw a dashed border, so an unknown challenge's pill is drawn here: dashed
# straight sides, and every other dash-length step of each rounded end.
static func _draw_dashed_border(label: Label) -> void:
	var color := label.get_theme_color(&"border_color")
	var width := float(label.get_theme_constant(&"border_width"))
	var middle := label.size.y / 2.0
	var radius := middle - width / 2.0
	var left := middle
	var right := label.size.x - middle
	label.draw_dashed_line(Vector2(left, width / 2.0), Vector2(right, width / 2.0), color, width, DASH_LENGTH)
	label.draw_dashed_line(Vector2(left, label.size.y - width / 2.0), Vector2(right, label.size.y - width / 2.0), color, width, DASH_LENGTH)
	var step := DASH_LENGTH / radius
	for i: int in range(0, ceili(PI / step), 2):
		var from := PI / 2.0 + i * step
		var to := minf(from + step, PI * 1.5)
		label.draw_arc(Vector2(left, middle), radius, from, to, 4, color, width)
		label.draw_arc(Vector2(right, middle), radius, from - PI, to - PI, 4, color, width)


func _show_challenges(dispatch: Dispatch) -> void:
	for quest: String in _chips:
		var unknown := dispatch.unknown_challenges(quest)
		if _unknown_shown.get(quest, -1) == unknown.size():
			continue
		_unknown_shown[quest] = unknown.size()
		# Every pill, after the meta line.
		for old: Node in _chips[quest].get_children().slice(1):
			_chips[quest].remove_child(old)
			old.queue_free()
		for challenge: String in Dispatch.QUESTS[quest]["challenges"]:
			_chips[quest].add_child(chip("?", &"PillUnknown") if challenge in unknown else chip(challenge, &"Pill"))


func _show_needs_you(dispatch: Dispatch) -> void:
	var waiting := dispatch.waiting_loot
	# The decision open stays open on the same loot when other loot comes or goes.
	if _deciding >= 0 and waiting != _loot_shown:
		_deciding = waiting.find(_loot_shown[_deciding])
	var ready := dispatch.ready_to_level()
	var stash := dispatch.adventurers.gear.stash if _deciding >= 0 else PackedStringArray()
	var unseen := dispatch.unseen_fallen()
	var shown := [waiting.duplicate(), unseen, ready, _deciding, stash.duplicate()]
	if shown == _needs_you_shown:
		return
	_needs_you_shown = shown
	_loot_shown = waiting.duplicate()
	for row: Node in _needs_you.get_children():
		_needs_you.remove_child(row)
		row.queue_free()
	for i: int in unseen:
		_needs_you.add_child(_fallen_row(i, dispatch.fallen[i]))
	for i: int in waiting.size():
		_needs_you.add_child(_decision(i, dispatch) if i == _deciding else _loot_row(i, waiting[i]))
	if not ready.is_empty():
		_needs_you.add_child(_level_up_row(ready, dispatch.adventurers.roster))
	_needs_you_count.text = str(dispatch.needs_you_count())
	_needs_you_header.visible = _needs_you.get_child_count() > 0
	_needs_you.visible = _needs_you_header.visible
	_done.visible = _deciding >= 0


# Opens the decision on the loot waiting at `index`, or closes it for -1, at once.
func _decide(index: int) -> void:
	_deciding = index
	_show_needs_you(_dispatch)


# The row for `waiting`, the loot at `index` that found the stash full, with Decide.
func _loot_row(index: int, waiting: Dictionary) -> Control:
	var item: String = waiting["item"]
	var decide := Button.new()
	decide.text = "Decide ›"
	decide.theme_type_variation = &"GoldLink"
	decide.pressed.connect(_decide.bind(index))
	var sub := "%s brought %s" % [Dispatch.QUESTS[waiting["quest"]]["name"], Gear.ITEMS[item]["name"]]
	return Touch.whole_card(_needs_you_row(Adventurer.item_icon(item, 3), _label("Stash full", &"AlertTitle"), sub, decide), decide)


# The row saying who died in `death`, the death at `index` in Dispatch.fallen, and on which elite,
# with OK, which marks it seen.
func _fallen_row(index: int, death: Dictionary) -> Control:
	var ok := Button.new()
	ok.text = "OK"
	ok.theme_type_variation = &"GoldLink"
	ok.pressed.connect(fallen_seen.emit.bind(index))
	var who: String = death["name"]
	return Touch.whole_card(_needs_you_row(token(who.left(1), {}), _label(who + " fell", &"AlertTitle"), Dispatch.QUESTS[death["quest"]]["name"], ok), ok)


# A closed Needs you row: `picture`, then `title` over `sub` on one line, then `action`.
static func _needs_you_row(picture: Control, title: Label, sub: String, action: Button) -> PanelContainer:
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_child(title)
	words.add_child(one_line(sub, &"Caption"))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", ROW_GAP_PX)
	line.add_child(picture)
	line.add_child(words)
	line.add_child(action)
	var row := PanelContainer.new()
	row.theme_type_variation = &"CardRow"
	row.add_child(line)
	return row


# The decision on the loot waiting at `index` in `dispatch`: the loot, then every stash item, the
# cheapest first, each with Swap at the gold it sells for, then Let it go.
func _decision(index: int, dispatch: Dispatch) -> Control:
	var waiting := dispatch.waiting_loot[index]
	var gear := dispatch.adventurers.gear
	var item: String = waiting["item"]
	var title := _label("Stash full", &"AlertTitle")
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	var who_text: String = Dispatch.QUESTS[waiting["quest"]]["name"]
	# A party all dead names nobody.
	var names := _names(waiting["party"], dispatch.adventurers.roster)
	if not names.is_empty():
		who_text += " · " + names
	var who := _label(who_text, &"Secondary")
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 24)
	top.add_child(title)
	top.add_child(who)
	var loot := PanelContainer.new()
	loot.theme_type_variation = &"CardGold"
	var quality: String = Gear.ITEMS[item]["quality"]
	var quality_label := _label(quality + " ·", StringName("Item" + quality))
	quality_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var bonus := Adventurer.bonus_label(item)
	bonus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var quality_and_bonus := HBoxContainer.new()
	quality_and_bonus.add_theme_constant_override("separation", 16)
	quality_and_bonus.add_child(quality_label)
	quality_and_bonus.add_child(bonus)
	loot.add_child(_item_line(item, 3, _label(Gear.ITEMS[item]["name"], &"RowTitle"), quality_and_bonus))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	box.add_child(top)
	box.add_child(loot)
	box.add_child(_label("Make room: one of these goes, sold at its Armory price.", &"Secondary"))
	var order: Array = range(gear.stash.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		var price_a := Gear.price(gear.stash[a])
		var price_b := Gear.price(gear.stash[b])
		return price_a < price_b or (price_a == price_b and a < b))
	var stash_list := VBoxContainer.new()
	stash_list.add_theme_constant_override("separation", 0)
	for at: int in order:
		var stash_item := gear.stash[at]
		var swap := Button.new()
		swap.text = "Swap · +%dg" % Gear.price(stash_item)
		swap.theme_type_variation = &"SmallButton"
		swap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swap.pressed.connect(swap_pressed.emit.bind(index, stash_item))
		var kind := _label("%s · %s" % [Gear.ITEMS[stash_item]["quality"], Gear.SLOTS[Gear.ITEMS[stash_item]["slot"]]], &"Caption")
		kind.autowrap_mode = TextServer.AUTOWRAP_OFF
		kind.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var line := _item_line(stash_item, 2, Adventurer.item_name(stash_item), kind)
		line.add_child(swap)
		var row := PanelContainer.new()
		row.theme_type_variation = &"ProgressRow"
		row.add_child(line)
		stash_list.add_child(Touch.whole_card(row, swap))
	box.add_child(stash_list)
	var let_go := Button.new()
	let_go.text = "Let the %s go" % Gear.ITEMS[item]["name"]
	let_go.theme_type_variation = &"AlertLink"
	let_go.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	let_go.pressed.connect(let_go_pressed.emit.bind(index))
	box.add_child(let_go)
	var row := PanelContainer.new()
	row.theme_type_variation = &"CardRow"
	row.add_child(box)
	return row


# `item`'s icon at `icon_scale` beside `name_label` with `details` under it.
static func _item_line(item: String, icon_scale: int, name_label: Label, details: Control) -> HBoxContainer:
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_child(name_label)
	words.add_child(details)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 24)
	line.add_child(Adventurer.item_icon(item, icon_scale))
	line.add_child(words)
	return line


# The row naming everyone in `ready` with a level-up ready, whose Open levels up the first.
func _level_up_row(ready: PackedStringArray, roster: Dictionary) -> Control:
	var open := Button.new()
	open.text = "Open ›"
	open.theme_type_variation = &"GoldLink"
	open.pressed.connect(level_up_pressed.emit.bind(ready[0]))
	return Touch.whole_card(_needs_you_row(_tokens(ready, roster), _label("Level up ready", &"RowTitle"), _names(ready, roster), open), open)


# The names of those in `party` still in `roster`, comma-separated.
static func _names(party: PackedStringArray, roster: Dictionary) -> String:
	var names := PackedStringArray()
	for adventurer: String in party:
		if adventurer in roster:
			names.append(roster[adventurer]["name"])
	return ", ".join(names)


# A row per party, rebuilt only when a party is made, goes or changes members; each tick changes only
# its words, bar and switch.
func _show_parties(dispatch: Dispatch, now: int) -> void:
	var parties := dispatch.adventurers.parties
	var groups := parties.groups()
	if groups != _parties_shown:
		_parties_shown = groups
		for row: Node in _party_list.get_children():
			_party_list.remove_child(row)
			row.queue_free()
		_party_rows.clear()
		for party: Dictionary in parties.parties:
			_party_list.add_child(_party_row(party["id"], party["members"], dispatch.adventurers.roster))
		_parties_section.visible = not groups.is_empty()
		_party_list.visible = _parties_section.visible
	for id: String in _party_rows:
		_show_party(_party_rows[id], id, dispatch, now)


# The row of party `id` of `members` in `roster`: its rank pill, name and faces over where it is in
# its cycle, and at the right its Auto switch over its mode, then its Elite switch.
func _party_row(id: String, members: PackedStringArray, roster: Dictionary) -> PanelContainer:
	var parts := PartyRow.new()
	parts.rank = chip("", &"Pill")
	parts.rank.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parts.name = one_line("", &"RowTitle")
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	# The pill first, so it lines up from row to row, as in the party picker.
	top.add_child(parts.rank)
	top.add_child(parts.name)
	parts.top = top
	parts.faces = _tokens(members, roster)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parts.middle = HBoxContainer.new()
	parts.middle.add_theme_constant_override("separation", ROW_GAP_PX)
	parts.middle.add_child(gap)
	parts.status = one_line("", &"Caption")
	# Most of the line for the words, so "Healing · out again in" fits beside its bar.
	parts.status.size_flags_stretch_ratio = 2.0
	parts.bar = ProgressBar.new()
	parts.bar.show_percentage = false
	parts.bar.step = 1.0
	parts.bar.custom_minimum_size = Vector2(0, PARTY_BAR_PX)
	parts.bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parts.bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parts.time = _label("", &"Numbers")
	parts.time.autowrap_mode = TextServer.AUTOWRAP_OFF
	parts.time.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var status := HBoxContainer.new()
	status.add_theme_constant_override("separation", 16)
	status.add_child(parts.status)
	status.add_child(parts.bar)
	status.add_child(parts.time)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_child(top)
	words.add_child(parts.middle)
	words.add_child(status)
	parts.auto = Button.new()
	parts.auto.theme_type_variation = &"Switch"
	parts.auto.toggle_mode = true
	parts.auto.custom_minimum_size = SWITCH_SIZE_PX
	parts.auto.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parts.auto.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parts.auto.draw.connect(_draw_knob.bind(parts.auto))
	parts.auto.toggled.connect(func(on: bool) -> void: auto_toggled.emit(id, on))
	parts.off = _label("Auto", &"Caption")
	parts.off.autowrap_mode = TextServer.AUTOWRAP_OFF
	parts.off.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parts.mode = Button.new()
	parts.mode.theme_type_variation = &"SmallLink"
	parts.mode.pressed.connect(mode_toggled.emit.bind(id))
	parts.elite = Button.new()
	parts.elite.theme_type_variation = &"Switch"
	parts.elite.toggle_mode = true
	parts.elite.custom_minimum_size = ELITE_SWITCH_SIZE_PX
	parts.elite.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parts.elite.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parts.elite.draw.connect(_draw_knob.bind(parts.elite))
	parts.elite.toggled.connect(func(on: bool) -> void: elite_toggled.emit(id, on))
	parts.elite_label = _label("Elite", &"Caption")
	parts.elite_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	parts.elite_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parts.right = BoxContainer.new()
	parts.right.alignment = BoxContainer.ALIGNMENT_CENTER
	parts.right.add_theme_constant_override("separation", 16)
	parts.right.add_child(parts.auto)
	parts.right.add_child(parts.off)
	parts.right.add_child(parts.mode)
	parts.right.add_child(parts.elite)
	parts.right.add_child(parts.elite_label)
	parts.line = HBoxContainer.new()
	parts.line.add_theme_constant_override("separation", ROW_GAP_PX)
	parts.line.add_child(words)
	var row := PanelContainer.new()
	row.theme_type_variation = &"CardRow"
	row.add_child(parts.line)
	_party_rows[id] = parts
	_place_parts(parts)
	return row


# In portrait, the faces follow the name and the Auto switch is a column at the right of the row, as
# in the design; in landscape both go on the line between the name and where the party is.
func _place_parts(parts: PartyRow) -> void:
	var faces_in := parts.middle if _landscape else parts.top
	var right_in := parts.middle if _landscape else parts.line
	for part: Control in [parts.faces, parts.right]:
		if part.get_parent() != null:
			part.get_parent().remove_child(part)
	faces_in.add_child(parts.faces)
	faces_in.move_child(parts.faces, 0 if _landscape else -1)
	right_in.add_child(parts.right)
	parts.right.vertical = not _landscape
	parts.right.custom_minimum_size.x = 0.0 if _landscape else AUTO_COLUMN_PX
	parts.middle.visible = _landscape


# A Switch's knob, at its right while on, drawn over the track its style draws.
static func _draw_knob(switch: Button) -> void:
	var radius := switch.size.y / 2.0 - KNOB_INSET_PX
	var x := switch.size.x - switch.size.y / 2.0 if switch.button_pressed else switch.size.y / 2.0
	switch.draw_circle(Vector2(x, switch.size.y / 2.0), radius, switch.get_theme_color(&"knob_color"))


# Shows party `id` in `parts` as it is at `now`: its name and rank, its Auto, and where it is: its
# quest with a bar and the time left while out; else stopped on loot waiting for the player; home
# with Auto off; and with Auto on, stopped on someone training, healing with a bar and the time
# until it is ready, or waiting for a quest that suits it.
func _show_party(parts: PartyRow, id: String, dispatch: Dispatch, now: int) -> void:
	var parties := dispatch.adventurers.parties
	var members: PackedStringArray = parties.party(id)["members"]
	var on := parties.auto(id) and _auto_unlocked
	parts.right.visible = _auto_unlocked
	parts.name.text = parties.party(id)["name"]
	parts.rank.text = parties.rank(id, dispatch.adventurers.roster)
	parts.auto.set_pressed_no_signal(on)
	parts.off.visible = not on
	parts.mode.visible = on
	parts.mode.text = "Auto · Bold" if parties.mode(id) == Parties.BOLD else "Auto · Safe"
	parts.elite.visible = _rank_c
	parts.elite_label.visible = _rank_c
	parts.elite.set_pressed_no_signal(parties.elite_auto(id))
	var outing := {}
	for each: Dictionary in dispatch.outings:
		if members[0] in each["party"]:
			outing = each
	var look := &"Caption"
	var from := 0
	var to := 0
	if not outing.is_empty():
		parts.status.text = Dispatch.QUESTS[outing["quest"]]["name"]
		from = outing["since"]
		to = dispatch.back_at(outing)
	elif Array(members).any(dispatch.loot_waiting):
		parts.status.text = "Stopped · loot waiting"
		look = &"AlertSmall"
	elif not on:
		parts.status.text = "Home"
	else:
		var ready_in := Auto.seconds_to_ready(dispatch, id, now)
		if ready_in < 0:
			parts.status.text = "Stopped · training"
			look = &"AlertSmall"
		elif ready_in > 0:
			parts.status.text = "Healing · out again in"
			# Healing started when they came home.
			for adventurer: String in members:
				from = maxi(from, int(dispatch.wounds.get(adventurer, {}).get("at", 0)))
			to = maxi(now, dispatch.checked_at) + ready_in
		else:
			parts.status.text = "Waiting for a quest"
	parts.status.theme_type_variation = look
	parts.bar.visible = to > 0
	parts.time.visible = parts.bar.visible
	if parts.bar.visible:
		var left := maxi(0, to - maxi(now, dispatch.checked_at))
		parts.bar.theme_type_variation = &"HealthBar" if outing.is_empty() else &"GoldBar"
		parts.bar.max_value = to - from
		parts.bar.value = to - from - left
		parts.time.text = Duration.label(left)


func _tokens(party: PackedStringArray, roster: Dictionary) -> HBoxContainer:
	var stack := HBoxContainer.new()
	stack.theme_type_variation = &"TokenStack"
	for adventurer: String in party:
		stack.add_child(token(adventurer, roster))
	return stack


# `card` over a ListRow button its size, so a tap anywhere on it calls `on_tap` and the row lights
# while pressed: nothing on the card takes the press.
static func _tap_row(card: Control, on_tap: Callable) -> MarginContainer:
	var tap := Button.new()
	tap.theme_type_variation = &"ListRow"
	tap.pressed.connect(on_tap)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for part: Node in card.find_children("*", "Control", true, false):
		(part as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A MarginContainer stacks its children, so the button is the card's size, under it.
	var stack := MarginContainer.new()
	stack.add_child(tap)
	stack.add_child(card)
	return stack


## Draws `list`'s one card, a RowList's panel, behind its rows, with a thin line in each gap
## between two shown rows, internal ones included; every compact list connects its draw to this.
static func draw_card(list: VBoxContainer) -> void:
	var card := list.get_theme_stylebox(&"panel") as StyleBoxFlat
	list.draw_style_box(card, Rect2(Vector2.ZERO, list.size))
	var gap := list.get_theme_constant(&"separation")
	var divider := list.get_theme_color(&"divider")
	# Between the card's side borders, so a coloured border stays whole.
	var width := list.size.x - card.border_width_left - card.border_width_right
	var first := true
	for row: Node in list.get_children(true):
		var shown := row as Control
		if not shown.visible:
			continue
		if not first:
			list.draw_rect(Rect2(card.border_width_left, shown.position.y - gap, width, gap), divider)
		first = false


## A label on one line that takes the room left and cuts its text short with "…" when it runs out.
static func one_line(text: String, variation: StringName) -> Label:
	var label := _label(text, variation)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


static func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.theme_type_variation = variation
	return label
