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

## The length of each dash in an unknown challenge's chip border.
const DASH_LENGTH: float = 12.0
## How many times larger than its pixels a face shows: a whole number, so the pixels stay crisp.
const FACE_SCALE: int = 3
## How many times larger than its pixels a figure shows: the design's 80 × 108 on its 390-wide
## phone, on the 1080-wide screen, to a whole number.
const FIGURE_SCALE: int = 7

## What each adventurer wears, Gear.worn itself, so a token shows it; main sets it when a game opens.
static var worn: Dictionary[String, Dictionary] = {}
## Each person's look shown so far, by their face seed: one per adventurer or candidate shown.
static var _looks: Dictionary[int, Look] = {}

var _rows: Dictionary[String, Control] = {}
## Each quest's challenge chips, and how many of them were unknown when last shown, so they change
## only when a return or the Map room reveals one.
var _chips: Dictionary[String, HFlowContainer] = {}
var _unknown_shown: Dictionary[String, int] = {}
## Each quest's rank, time and gold line, which ends with its time left on the board, so it
## changes each second without rebuilding the row.
var _meta: Dictionary[String, Label] = {}
## The board's slots shown, so the rows change only when the board does.
var _shown: PackedStringArray = PackedStringArray()
## The one line under the quests for the empty slots: the soonest refill.
var _refill: Label
## What the Needs you rows were built from: the loot waiting, who has a level-up ready, the decision
## open and, while one is, the stash. They are rebuilt only when one of those changes.
var _needs_you_shown: Array = []
## The loot waiting as last shown, and where in it the loot whose decision is open is; -1 for none.
var _loot_shown: Array[Dictionary] = []
var _deciding: int = -1
## The dispatch last shown, so opening or closing a decision shows at once.
var _dispatch: Dispatch
## The parties out the rows were built for, so they are rebuilt only when those change;
## `_out_rows` are their parts that change with time, in the same order.
var _outings_shown: Array[Dictionary] = []
var _out_rows: Array[OutRow] = []

@onready var _needs_you_header: Control = $Scroll/Box/NeedsYouHeader
@onready var _needs_you_count: Label = $Scroll/Box/NeedsYouHeader/Count
@onready var _done: Button = $Scroll/Box/NeedsYouHeader/Done
@onready var _needs_you: VBoxContainer = $Scroll/Box/NeedsYou
@onready var _out_section: Control = $Scroll/Box/OutSection
@onready var _out: VBoxContainer = $Scroll/Box/Out
@onready var _list: VBoxContainer = $Scroll/Box/List
@onready var _parties: Control = $Scroll/Box/Header/Parties
@onready var _parties_count: Label = $Scroll/Box/Header/Parties/Count


## A party-out row's parts that change each second.
class OutRow extends RefCounted:
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
	for quest: String in Dispatch.QUESTS:
		var info: Dictionary = Dispatch.QUESTS[quest]
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		words.add_child(_label(info["name"], &"Heading"))
		_meta[quest] = _label("", &"Meta")
		_meta[quest].name = "Meta"
		words.add_child(_meta[quest])
		var chips := HFlowContainer.new()
		chips.theme_type_variation = &"Chips"
		words.add_child(chips)
		_chips[quest] = chips
		var send := Button.new()
		send.text = "Send party"
		send.theme_type_variation = &"GoldButton"
		send.custom_minimum_size = Vector2(0, 122)
		send.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		send.pressed.connect(send_pressed.emit.bind(quest))
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 32)
		line.add_child(words)
		line.add_child(send)
		var row := PanelContainer.new()
		row.add_child(line)
		_rows[quest] = Touch.whole_card(row, send)
		_rows[quest].visible = false
		_list.add_child(_rows[quest])
	_refill = _label("", &"Secondary")
	_list.add_child(_refill)
	_done.pressed.connect(_decide.bind(-1))


## Landscape shows how many parties are out beside the title.
func set_landscape(landscape: bool) -> void:
	_parties.visible = landscape


## Shows what needs the player in `dispatch` (loot that found the stash full, and level-ups ready)
## and the parties out at `now`, then the quests in `board`'s slots in order, each with the time
## until it leaves the board, and under them, while a slot is empty, the soonest refill. An unknown
## challenge shows the time to its reveal while the Map room is revealing it.
func show_board(board: Board, dispatch: Dispatch, now: int) -> void:
	_dispatch = dispatch
	_parties_count.text = str(dispatch.outings.size())
	_show_needs_you(dispatch)
	_show_out(dispatch, now)
	_show_challenges(dispatch)
	if board.slots != _shown:
		_shown = board.slots.duplicate()
		for quest: String in _rows:
			_rows[quest].visible = quest in _shown
		# The quests first, in slot order, before the hidden rows and the refill line.
		var at := 0
		for quest: String in _shown:
			if quest != "":
				_list.move_child(_rows[quest], at)
				at += 1
	var left := board.seconds_to_next_refill(dispatch, now)
	_refill.visible = left >= 0
	_refill.text = "New quest in " + Duration.label(left) if left > 0 else "New quest when one is free"
	for quest: String in _shown:
		if quest == "":
			continue
		var info: Dictionary = Dispatch.QUESTS[quest]
		# A no-break space keeps the time left with "leaves" where the line wraps.
		_meta[quest].text = "Rank %s · %s · %d gold · leaves%s%s" % [info["rank"], Duration.label(info["seconds"]), info["gold"], String.chr(0xA0), Duration.label(board.seconds_to_leave(quest, dispatch, now))]
		var reveal := board.seconds_to_reveal(quest, dispatch, now)
		for chip_shown: Label in _chips[quest].get_children():
			if chip_shown.theme_type_variation == &"ChipUnknown":
				chip_shown.text = "? · " + Duration.label(reveal) if reveal > 0 else "?"


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
## a dashed border.
static func chip(text: String, variation: StringName) -> Label:
	var label := _label(text, variation)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	if variation == &"ChipUnknown":
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
		for old: Node in _chips[quest].get_children():
			old.queue_free()
		for challenge: String in Dispatch.QUESTS[quest]["challenges"]:
			_chips[quest].add_child(chip("?", &"ChipUnknown") if challenge in unknown else chip(challenge, &"Chip"))


func _show_needs_you(dispatch: Dispatch) -> void:
	var waiting := dispatch.waiting_loot
	# The decision open stays open on the same loot when other loot comes or goes.
	if _deciding >= 0 and waiting != _loot_shown:
		_deciding = waiting.find(_loot_shown[_deciding])
	var ready := dispatch.ready_to_level()
	var stash := dispatch.adventurers.gear.stash if _deciding >= 0 else PackedStringArray()
	var shown := [waiting.duplicate(), ready, _deciding, stash.duplicate()]
	if shown == _needs_you_shown:
		return
	_needs_you_shown = shown
	_loot_shown = waiting.duplicate()
	for row: Node in _needs_you.get_children():
		_needs_you.remove_child(row)
		row.queue_free()
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
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_child(_label("Stash full", &"AlertTitle"))
	words.add_child(_label("%s brought %s" % [Dispatch.QUESTS[waiting["quest"]]["name"], Gear.ITEMS[item]["name"]], &"Secondary"))
	var decide := Button.new()
	decide.text = "Decide ›"
	decide.theme_type_variation = &"GoldLink"
	decide.pressed.connect(_decide.bind(index))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 32)
	line.add_child(Adventurer.item_icon(item, 3))
	line.add_child(words)
	line.add_child(decide)
	var row := PanelContainer.new()
	row.theme_type_variation = &"NeedsYouRow"
	row.add_child(line)
	return Touch.whole_card(row, decide)


# The decision on the loot waiting at `index` in `dispatch`: the loot, then every stash item, the
# cheapest first, each with Swap at the gold it sells for, then Let it go.
func _decision(index: int, dispatch: Dispatch) -> Control:
	var waiting := dispatch.waiting_loot[index]
	var gear := dispatch.adventurers.gear
	var item: String = waiting["item"]
	var title := _label("Stash full · %d / %d" % [gear.stash.size(), gear.stash_cap], &"AlertTitle")
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	var who := _label("%s · %s" % [Dispatch.QUESTS[waiting["quest"]]["name"], _names(waiting["party"], dispatch.adventurers.roster)], &"Secondary")
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
	row.theme_type_variation = &"NeedsYouRow"
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
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_child(_label("Level up ready", &"RowTitle"))
	words.add_child(_label(_names(ready, roster), &"Secondary"))
	var open := Button.new()
	open.text = "Open ›"
	open.theme_type_variation = &"GoldLink"
	open.pressed.connect(level_up_pressed.emit.bind(ready[0]))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 32)
	line.add_child(_tokens(ready, roster))
	line.add_child(words)
	line.add_child(open)
	var row := PanelContainer.new()
	row.theme_type_variation = &"NeedsYouRow"
	row.add_child(line)
	return Touch.whole_card(row, open)


# The names of those in `party` still in `roster`, comma-separated.
static func _names(party: PackedStringArray, roster: Dictionary) -> String:
	var names := PackedStringArray()
	for adventurer: String in party:
		if adventurer in roster:
			names.append(roster[adventurer]["name"])
	return ", ".join(names)


func _show_out(dispatch: Dispatch, now: int) -> void:
	if dispatch.outings != _outings_shown:
		_outings_shown = dispatch.outings.duplicate()
		for row: Node in _out.get_children():
			row.queue_free()
		_out_rows.clear()
		for outing: Dictionary in _outings_shown:
			var quest: Dictionary = Dispatch.QUESTS[outing["quest"]]
			var title := _label(quest["name"], &"RowTitle")
			title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var reward := _label("%d gold" % quest["gold"], &"Meta")
			reward.autowrap_mode = TextServer.AUTOWRAP_OFF
			var heading := HBoxContainer.new()
			heading.add_child(title)
			heading.add_child(reward)
			var out := OutRow.new()
			out.bar = ProgressBar.new()
			out.bar.theme_type_variation = &"GoldBar"
			out.bar.show_percentage = false
			out.bar.step = 1.0
			out.bar.max_value = quest["seconds"]
			out.bar.custom_minimum_size = Vector2(0, 16)
			out.bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			out.bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			out.time = _label("", &"Numbers")
			out.time.autowrap_mode = TextServer.AUTOWRAP_OFF
			_out_rows.append(out)
			var progress := HBoxContainer.new()
			progress.add_theme_constant_override("separation", 32)
			progress.add_child(_tokens(outing["party"], dispatch.adventurers.roster))
			progress.add_child(out.bar)
			progress.add_child(out.time)
			var box := VBoxContainer.new()
			box.add_theme_constant_override("separation", 24)
			box.add_child(heading)
			box.add_child(progress)
			var row := PanelContainer.new()
			row.add_child(box)
			_out.add_child(row)
		_out_section.visible = not _outings_shown.is_empty()
		_out.visible = not _outings_shown.is_empty()
	for i: int in _out_rows.size():
		var left := dispatch.seconds_left(_outings_shown[i], now)
		_out_rows[i].bar.value = _out_rows[i].bar.max_value - left
		_out_rows[i].time.text = Duration.label(left)


func _tokens(party: PackedStringArray, roster: Dictionary) -> HBoxContainer:
	var stack := HBoxContainer.new()
	stack.theme_type_variation = &"TokenStack"
	for adventurer: String in party:
		stack.add_child(token(adventurer, roster))
	return stack


static func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.theme_type_variation = variation
	return label
