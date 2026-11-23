class_name Adventurer
extends Control

## The player is done looking at this adventurer.
signal back_pressed
## The player chose to level up `adventurer`, a key of Adventurers.roster.
signal level_up_pressed(adventurer: String)
## The player chose to promote `adventurer` to their next rank.
signal promote_pressed(adventurer: String)
## The player tapped `adventurer`'s gear `slot`, a key of Gear.SLOTS, to change what goes in it.
signal slot_pressed(adventurer: String, slot: String)
## The player chose to put `adventurer` in training.
signal train_pressed(adventurer: String)
## The player chose to end `adventurer`'s training and bank its XP.
signal stop_training_pressed(adventurer: String)
## The player asked to dismiss `adventurer` from the guild.
signal dismiss_pressed(adventurer: String)
## The player swiped to the next adventurer in roster order (`step` 1) or the previous (`step` -1).
signal swiped(step: int)

## A stat at this value fills its bar.
const STAT_BAR_FULL: int = 20
## The width a health row keeps for its text, and the XP numbers under it, so their bars line up:
## the design's 64 dp.
const HEALTH_TEXT_WIDTH_PX: float = 177.0
## The small type of a stat chip's name, its total, and what gear adds to it.
const CHIP_NAME_FONT_PX: int = 33
const CHIP_TOTAL_FONT_PX: int = 36
const CHIP_GEAR_FONT_PX: int = 28
## A gear slot's box, which an item's icon at scale 5 fills, and the "+" in an empty one that a
## stash item fits.
const SLOT_BOX_PX: int = 172
const SLOT_PLUS_FONT_PX: int = 50
## The round badge counting the stash items that fit a slot, and how far it sticks out past the
## box's top-right corner: the design's 16 and 5 dp.
const FIT_BADGE_PX: int = 44
const FIT_BADGE_OVERHANG_PX: int = 14
## How many gear slots go to a row: four in portrait, all eight in landscape.
const GEAR_COLUMNS_PORTRAIT: int = 4
const GEAR_COLUMNS_LANDSCAPE: int = 8
## The gaps between the sections, the header's lines and the stat chips' rows: as the scene has them
## in portrait, tighter in landscape so everything fits above Back without scrolling.
const SECTION_GAP_PX: Vector2i = Vector2i(22, 16)
const HEADER_LINE_GAP_PX: Vector2i = Vector2i(14, 6)
const CHIP_ROW_GAP_PX: Vector2i = Vector2i(11, 6)
## How tall Back is: as the scene has it in portrait; in landscape a small button, so a header with
## Level up in it still fits.
const BACK_HEIGHT_PX: Vector2i = Vector2i(144, Roster.SMALL_BUTTON_PX)
## A press-drag-release at least this far sideways, and further sideways than up or down, is a swipe.
const SWIPE_MIN_PX: float = 120.0

var _adventurer: String = ""
## Each stat's chip, its total, and what gear adds to it.
var _chips: Dictionary[String, PanelContainer] = {}
var _values: Dictionary[String, Label] = {}
var _gear_values: Dictionary[String, Label] = {}
var _health: HBoxContainer
## The adventurer, their gear and how many stash items fit each slot, as shown, so the gear is
## rebuilt only when these change.
var _gear_shown: Array = []
## Whether the landscape layout shows, which leaves out the notes under the stats.
var _landscape: bool = false
## Whether a press that started on this screen is held, so its release may be a swipe.
var _press_held: bool = false
## Where the held press started, in viewport pixels.
var _press_at: Vector2 = Vector2.ZERO

@onready var _figure: TextureRect = $Box/Scroll/Content/Card/Header/Row/Figure
@onready var _name: Label = $Box/Scroll/Content/Card/Header/Row/Words/NameLine/Name
@onready var _status: Label = $Box/Scroll/Content/Card/Header/Row/Words/NameLine/Status
@onready var _details: Label = $Box/Scroll/Content/Card/Header/Row/Words/Details
@onready var _level_up: Button = $Box/Scroll/Content/Card/Header/Row/Words/LevelUp
@onready var _xp: HBoxContainer = $Box/Scroll/Content/Card/Header/Row/Words/Xp
@onready var _xp_bar: ProgressBar = $Box/Scroll/Content/Card/Header/Row/Words/Xp/Bar
@onready var _xp_text: Label = $Box/Scroll/Content/Card/Header/Row/Words/Xp/Text
@onready var _promote: Button = $Box/Scroll/Content/Card/Header/Row/Words/Actions/Promote
@onready var _promote_reason: Label = $Box/Scroll/Content/Card/Header/Row/Words/PromoteReason
@onready var _training_xp: Label = $Box/Scroll/Content/Card/Header/Row/Words/Actions/TrainingXp
@onready var _stop: Button = $Box/Scroll/Content/Card/Header/Row/Words/Actions/Stop
@onready var _train: Button = $Box/Scroll/Content/Card/Header/Row/Words/Actions/Train
@onready var _dismiss: Button = $Box/Scroll/Content/Card/Header/Row/Words/Actions/Dismiss
@onready var _last_level_up: Label = $Box/Scroll/Content/Card/Stats/Rows/LastLevelUp
@onready var _training_notes: Label = $Box/Scroll/Content/Card/Stats/Rows/TrainingNotes
## The key to the gear badges, shown while any slot has stash items that fit.
@onready var _fit_key: Control = $Box/Scroll/Content/GearColumn/Line/FitKey
@onready var _gear: GridContainer = $Box/Scroll/Content/GearColumn/Gear


func _ready() -> void:
	# One chip per stat, three to a row: its name, then its total and what gear adds.
	var grid := $Box/Scroll/Content/Card/Stats/Rows/Grid as GridContainer
	for stat: String in Adventurers.STATS:
		var name_label := Label.new()
		name_label.text = Adventurers.STATS[stat]
		name_label.theme_type_variation = &"Secondary"
		name_label.add_theme_font_size_override(&"font_size", CHIP_NAME_FONT_PX)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var value := Label.new()
		value.theme_type_variation = &"Numbers"
		value.add_theme_font_size_override(&"font_size", CHIP_TOTAL_FONT_PX)
		var from_gear := Label.new()
		from_gear.theme_type_variation = &"GoldAmount"
		from_gear.add_theme_font_size_override(&"font_size", CHIP_GEAR_FONT_PX)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		line.add_child(name_label)
		line.add_child(value)
		line.add_child(from_gear)
		var chip := PanelContainer.new()
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.add_child(line)
		_chips[stat] = chip
		_values[stat] = value
		_gear_values[stat] = from_gear
		grid.add_child(chip)
	# Thin and small, as the XP bar under it.
	_health = health_row()
	_health.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(_health.get_child(0) as Control).custom_minimum_size.y = Roster.HEALTH_BAR_PX
	(_health.get_child(1) as Label).add_theme_font_size_override(&"font_size", Roster.NUMBERS_FONT_PX)
	($Box/Scroll/Content/Card/Header/Row/Words/Hp as HBoxContainer).add_child(_health)
	_xp_text.custom_minimum_size.x = HEALTH_TEXT_WIDTH_PX
	_level_up.pressed.connect(func() -> void: level_up_pressed.emit(_adventurer))
	_promote.pressed.connect(func() -> void: promote_pressed.emit(_adventurer))
	_train.pressed.connect(func() -> void: train_pressed.emit(_adventurer))
	_stop.pressed.connect(func() -> void: stop_training_pressed.emit(_adventurer))
	_dismiss.pressed.connect(func() -> void: dismiss_pressed.emit(_adventurer))
	($Box/Back as Button).pressed.connect(back_pressed.emit)


# Watched here, not in _gui_input: the scroll container and the buttons take the drags and presses
# first. Nothing is marked handled, so they still get every event. Only mouse events are read: touch
# arrives as the mouse events Godot emulates from it (on by default), the same ones buttons press on,
# so a swipe counts once.
func _input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT or not is_visible_in_tree():
		return
	if click.pressed:
		_press_held = get_global_rect().has_point(click.position)
		_press_at = click.position
		return
	var held := _press_held
	_press_held = false
	if not held or click.canceled:
		return
	# A swipe is far past the tap's slop, so Touch has already kept the button it started on from
	# firing.
	var travel := click.position - _press_at
	if absf(travel.x) >= SWIPE_MIN_PX and absf(travel.x) > absf(travel.y):
		# Swiping left brings the next adventurer in, as turning a page does.
		swiped.emit(1 if travel.x < 0 else -1)


## The header and stats sit over the gear either way. Landscape fits all of it and Back on one
## screen: all eight gear slots in one row, tighter cards and gaps, Promote's refusal beside the
## buttons, and no section label lines or notes under the stats. Portrait sets the gear four to a row.
func set_landscape(landscape: bool) -> void:
	_landscape = landscape
	var pick := func(gaps: Vector2i) -> int: return gaps.y if landscape else gaps.x
	_gear.columns = GEAR_COLUMNS_LANDSCAPE if landscape else GEAR_COLUMNS_PORTRAIT
	for card: PanelContainer in [$Box/Scroll/Content/Card/Header, $Box/Scroll/Content/Card/Stats]:
		card.theme_type_variation = &"CardTight" if landscape else &""
	for line: Control in [$Box/Scroll/Content/Card/Stats/Rows/Line, $Box/Scroll/Content/GearColumn/Line]:
		line.visible = not landscape
	for box: Control in [$Box/Scroll/Content, $Box/Scroll/Content/Card, $Box/Scroll/Content/GearColumn]:
		box.add_theme_constant_override(&"separation", pick.call(SECTION_GAP_PX))
	var words := $Box/Scroll/Content/Card/Header/Row/Words as VBoxContainer
	words.add_theme_constant_override(&"separation", pick.call(HEADER_LINE_GAP_PX))
	($Box/Scroll/Content/Card/Stats/Rows/Grid as GridContainer).add_theme_constant_override(&"v_separation", pick.call(CHIP_ROW_GAP_PX))
	var back := $Box/Back as Button
	back.custom_minimum_size.y = pick.call(BACK_HEIGHT_PX)
	if landscape:
		back.add_theme_font_size_override(&"font_size", Roster.SMALL_FONT_PX)
	else:
		back.remove_theme_font_size_override(&"font_size")
	# The wide landscape header has room for the refusal on the buttons' row, on one line.
	var actions := $Box/Scroll/Content/Card/Header/Row/Words/Actions as Control
	_promote_reason.reparent(actions if landscape else words, false)
	if not landscape:
		words.move_child(_promote_reason, actions.get_index() + 1)
	_promote_reason.autowrap_mode = TextServer.AUTOWRAP_OFF if landscape else TextServer.AUTOWRAP_WORD_SMART
	_show_notes()


## Shows `adventurer` as `dispatch` has them at `now`: Promote once they reach the level their next
## rank needs, disabled with the reason when `gold` is short or they are out; Train only when one of
## `training_places` would take them now; Dismiss while they are home and not the last, disabled with
## the reason while something else keeps them.
func show_adventurer(adventurer: String, dispatch: Dispatch, gold: Gold, training_places: int, now: int) -> void:
	_adventurer = adventurer
	var adventurers := dispatch.adventurers
	var info: Dictionary = adventurers.roster[adventurer]
	_figure.texture = QuestBoard.figure(Faces.seed_of(adventurer, info), adventurers.gear.worn[adventurer])
	_name.text = info["name"]
	_status.text = dispatch.status(adventurer, now)
	_status.theme_type_variation = Roster.status_look(dispatch, adventurer, now)
	_details.text = Roster.details_line(adventurers, adventurer)
	show_health(_health, adventurer, dispatch, now)
	var xp: int = adventurers.xp[adventurer]
	var needed := adventurers.xp_needed(adventurer)
	_level_up.visible = adventurers.level_up_ready(adventurer)
	_level_up.text = "Level up · XP %d / %d" % [xp, needed]
	_xp.visible = not _level_up.visible
	_xp_bar.max_value = needed
	_xp_bar.value = xp
	_xp_text.text = "%d / %d" % [xp, needed]
	var next_rank := adventurers.next_rank(adventurer)
	var reason := adventurers.promotion_refusal(adventurer, gold, not dispatch.quest_of(adventurer).is_empty())
	# Promote shows from the level the next rank needs; short of gold or out on a quest, it says why.
	_promote.visible = adventurers.reached_promotion_level(adventurer)
	_promote.text = "" if next_rank.is_empty() else "Promote to %s · %dg" % [next_rank, Adventurers.PROMOTIONS[next_rank]["gold"]]
	_promote.disabled = not reason.is_empty()
	_promote_reason.text = reason
	_promote_reason.visible = _promote.visible and not reason.is_empty()
	var training := dispatch.training.has(adventurer)
	_training_xp.visible = training
	_training_xp.text = "Training · +%d XP" % dispatch.training_xp(adventurer, now)
	_stop.visible = training
	# Train shows only when training would start now.
	_train.visible = dispatch.training_refusal(adventurer, training_places, now).is_empty()
	var keeps_them := dispatch.dismiss_refusal(adventurer)
	_dismiss.visible = dispatch.quest_of(adventurer).is_empty() and adventurers.roster.size() > 1
	_dismiss.disabled = not keeps_them.is_empty()
	_dismiss.text = "Dismiss" if keeps_them.is_empty() else keeps_them
	var hint := dispatch.training_hint(adventurer, now)
	_training_notes.text = "" if hint.is_empty() else "Grows fastest in " + hint
	var title_stats := adventurers.title_stats(adventurer)
	for stat: String in Adventurers.STATS:
		var from_gear := adventurers.gear.bonus(adventurer, stat)
		_values[stat].text = str(adventurers.stat_total(adventurer, stat))
		_gear_values[stat].text = "+%d" % from_gear
		_gear_values[stat].visible = from_gear > 0
		_chips[stat].theme_type_variation = &"StatChipTitle" if stat in title_stats else &"StatChip"
	var history: Array = adventurers.history[adventurer]
	_last_level_up.text = "" if history.is_empty() else _history_line(history.back())
	_show_notes()
	var fits: Array[int] = []
	for slot: String in Gear.SLOTS:
		fits.append(adventurers.gear.fitting(slot).size())
	var gear_shown := [adventurer, adventurers.gear.worn[adventurer].duplicate(), fits]
	if gear_shown != _gear_shown:
		_gear_shown = gear_shown
		_show_gear(gear_shown[1], fits)


# The notes under the stats, the latest level-up and the training hint, each while it has words;
# none in landscape.
func _show_notes() -> void:
	for note: Label in [_last_level_up, _training_notes]:
		note.visible = not _landscape and not note.text.is_empty()


## An item's icon at a whole `scale` of its 28 × 28 pixels, so they stay crisp.
static func item_icon(item: String, scale: int) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = load("res://assets/items/%s.png" % item)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.custom_minimum_size = Vector2(28, 28) * scale
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


## A label with `item`'s name in its quality's colour.
static func item_name(item: String) -> Label:
	var label := Label.new()
	label.text = Gear.ITEMS[item]["name"]
	label.theme_type_variation = StringName("Item" + Gear.ITEMS[item]["quality"])
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## What `item` adds, "Strength +3 · Defence +4", in gold; "none" when nothing.
static func bonus_label(item: String) -> Label:
	var bonus: Dictionary = Gear.ITEMS[item]["bonus"]
	var parts := PackedStringArray()
	for stat: String in Adventurers.STATS:
		if bonus.has(stat):
			parts.append("%s +%d" % [Adventurers.STATS[stat], bonus[stat]])
	var label := Label.new()
	label.text = " · ".join(parts) if not parts.is_empty() else "none"
	label.theme_type_variation = &"GoldText" if not parts.is_empty() else &"Caption"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


# The eight slots, in Gear.SLOTS order: each item's icon over the slot's name, an empty slot dashed.
# A slot that `fits` (a count per slot, in the same order) says stash items fit is bordered gold and
# counts them in a badge on its corner, an empty one with a "+" inside. A tap anywhere on a slot,
# box or name, opens it.
func _show_gear(worn: Dictionary, fits: Array[int]) -> void:
	for cell: Node in _gear.get_children():
		cell.queue_free()
	_fit_key.visible = fits.any(func(count: int) -> bool: return count > 0)
	var slots := Gear.SLOTS.keys()
	for i: int in slots.size():
		var slot: String = slots[i]
		var item: String = worn.get(slot, "")
		var fit := fits[i]
		var box := PanelContainer.new()
		box.custom_minimum_size = Vector2(SLOT_BOX_PX, SLOT_BOX_PX)
		box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var slot_name := Label.new()
		slot_name.text = Gear.SLOTS[slot].to_upper()
		slot_name.theme_type_variation = &"Caption"
		slot_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 6)
		cell.add_child(box)
		cell.add_child(slot_name)
		if item.is_empty():
			box.theme_type_variation = &"ItemBoxEmptyFit" if fit > 0 else &"ItemBoxEmpty"
			box.draw.connect(_draw_dashed_box.bind(box))
			if fit > 0:
				var plus := Label.new()
				plus.text = "+"
				plus.theme_type_variation = &"GoldText"
				plus.add_theme_font_size_override(&"font_size", SLOT_PLUS_FONT_PX)
				plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				box.add_child(plus)
		else:
			box.theme_type_variation = &"ItemBoxFit" if fit > 0 else &"ItemBox"
			box.add_child(item_icon(item, 5))
		# A MarginContainer stacks its children, so the button covers the whole cell and the cell
		# sets the size.
		var open := Button.new()
		open.flat = true
		open.pressed.connect(slot_pressed.emit.bind(_adventurer, slot))
		if fit > 0:
			open.add_child(_fit_badge(fit))
		var stack := MarginContainer.new()
		stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stack.add_child(cell)
		stack.add_child(open)
		_gear.add_child(stack)


# The gold badge counting `fit` stash items, on the top-right corner of a slot's box. It hangs from
# the slot's button, which no container lays out, from the top centre, where the box is centred.
static func _fit_badge(fit: int) -> Label:
	var badge := Label.new()
	badge.text = str(fit)
	badge.theme_type_variation = &"FitBadge"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.anchor_left = 0.5
	badge.anchor_right = 0.5
	badge.offset_left = SLOT_BOX_PX / 2.0 + FIT_BADGE_OVERHANG_PX - FIT_BADGE_PX
	badge.offset_right = SLOT_BOX_PX / 2.0 + FIT_BADGE_OVERHANG_PX
	badge.offset_top = -FIT_BADGE_OVERHANG_PX
	badge.offset_bottom = FIT_BADGE_PX - FIT_BADGE_OVERHANG_PX
	return badge


# A StyleBox can't draw a dashed border, so an empty slot's box is drawn here.
static func _draw_dashed_box(box: PanelContainer) -> void:
	var color := box.get_theme_color(&"border_color")
	var width := float(box.get_theme_constant(&"border_width"))
	var inset := Rect2(Vector2.ONE * width / 2, box.size - Vector2.ONE * width)
	var corners: Array[Vector2] = [inset.position, Vector2(inset.end.x, inset.position.y), inset.end, Vector2(inset.position.x, inset.end.y)]
	for i: int in corners.size():
		box.draw_dashed_line(corners[i], corners[(i + 1) % corners.size()], color, width, 14.0)


## A row for one stat: its name, a bar and a value, the name in `look`.
static func stat_row(stat_name: String, look: StringName) -> HBoxContainer:
	var name_label := Label.new()
	name_label.text = stat_name
	name_label.theme_type_variation = look
	name_label.custom_minimum_size = Vector2(250, 0)
	var bar := ProgressBar.new()
	bar.theme_type_variation = &"OwnBar"
	bar.show_percentage = false
	bar.max_value = STAT_BAR_FULL
	bar.custom_minimum_size = Vector2(0, 22)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var value := Label.new()
	value.theme_type_variation = &"Numbers"
	value.custom_minimum_size = Vector2(80, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	row.add_child(name_label)
	row.add_child(bar)
	row.add_child(value)
	return row


## A row for health: a bar, then current / maximum and how long until full.
static func health_row() -> HBoxContainer:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.custom_minimum_size = Vector2(0, 16)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# A fixed width, so bars line up whether or not the time until full is shown.
	var text := Label.new()
	text.theme_type_variation = &"Meta"
	text.custom_minimum_size = Vector2(HEALTH_TEXT_WIDTH_PX, 0)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 24)
	row.add_child(bar)
	row.add_child(text)
	return row


## Fills a `health_row` with `adventurer`'s health at `now`, the bar red under a quarter.
static func show_health(row: HBoxContainer, adventurer: String, dispatch: Dispatch, now: int) -> void:
	var points := dispatch.health(adventurer, now)
	var most := dispatch.adventurers.max_health(adventurer)
	var bar := row.get_child(0) as ProgressBar
	bar.max_value = most
	bar.value = points
	bar.theme_type_variation = &"InjuryBar" if Dispatch.under_a_quarter(points, most) else &"HealthBar"
	var to_full := dispatch.seconds_to_full(adventurer, now)
	var text := row.get_child(1) as Label
	text.text = "%d / %d" % [points, most] if to_full == 0 else "%d / %d · full in %s" % [points, most, Duration.label(to_full)]


## XP toward the next level, in words for the player.
static func xp_line(xp: int, needed: int, next_level: int) -> String:
	return "XP %d / %d to level %d" % [xp, needed, next_level]


# "Level 3 · Strength +1 · Defence +2", naming only the stats that rose.
func _history_line(entry: Dictionary) -> String:
	var parts := PackedStringArray(["Level %d" % entry["level"]])
	for stat: String in Adventurers.STATS:
		var gain: int = entry["gains"].get(stat, 0)
		if gain > 0:
			parts.append("%s +%d" % [Adventurers.STATS[stat], gain])
	if parts.size() == 1:
		parts.append("no change")
	return " · ".join(parts)
