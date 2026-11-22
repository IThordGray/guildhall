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
## How many stats show side by side.
const STAT_COLUMNS: int = 3
## The size of what a worn item adds, in landscape's narrower gear cells.
const LANDSCAPE_BONUS_FONT_PX: int = 28
## The width a health row keeps for its text, so bars in a list line up.
const HEALTH_TEXT_WIDTH_PX: float = 480.0
## A press-drag-release at least this far sideways, and further sideways than up or down, is a swipe.
const SWIPE_MIN_PX: float = 120.0

var _adventurer: String = ""
## Each stat's bar: own in purple over own plus gear in gold.
var _bars: Dictionary[String, ProgressBar] = {}
var _own_bars: Dictionary[String, ProgressBar] = {}
var _values: Dictionary[String, Label] = {}
var _gear_values: Dictionary[String, Label] = {}
var _health: HBoxContainer
## The level-ups the history shows, so it is rebuilt only when they change.
var _history_shown: Array = []
## The adventurer and their gear, as shown, so the gear is rebuilt only when these change.
var _gear_shown: Array = []
## Whether the landscape layout shows, so the gear is built to fit its narrower column.
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
@onready var _xp: VBoxContainer = $Box/Scroll/Content/Card/Header/Row/Words/Xp
@onready var _xp_bar: ProgressBar = $Box/Scroll/Content/Card/Header/Row/Words/Xp/Bar
@onready var _xp_text: Label = $Box/Scroll/Content/Card/Header/Row/Words/Xp/Text
@onready var _promote: Button = $Box/Scroll/Content/Card/Header/Row/Words/Promote
@onready var _promote_reason: Label = $Box/Scroll/Content/Card/Header/Row/Words/PromoteReason
@onready var _training_xp: Label = $Box/Scroll/Content/Card/Header/Row/Words/Training/Xp
@onready var _stop: Button = $Box/Scroll/Content/Card/Header/Row/Words/Training/Stop
@onready var _train: Button = $Box/Scroll/Content/Card/Header/Row/Words/Training/Train
@onready var _dismiss: Button = $Box/Scroll/Content/Card/Header/Row/Words/Dismiss
@onready var _training_notes: Label = $Box/Scroll/Content/Card/Stats/Rows/TrainingNotes
@onready var _history: VBoxContainer = $Box/Scroll/Content/Card/Stats/Rows/History
@onready var _gear: GridContainer = $Box/Scroll/Content/GearColumn/Gear


func _ready() -> void:
	# Three across, each stat's name and value over its bar, so nine take no more height than four
	# rows did.
	var grid := GridContainer.new()
	grid.columns = STAT_COLUMNS
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 16)
	var rows := $Box/Scroll/Content/Card/Stats/Rows as VBoxContainer
	rows.add_child(grid)
	rows.move_child(grid, 0)
	for stat: String in Adventurers.STATS:
		var name_label := Label.new()
		name_label.text = Adventurers.STATS[stat]
		name_label.theme_type_variation = &"Secondary"
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value := Label.new()
		value.theme_type_variation = &"Numbers"
		var from_gear := Label.new()
		from_gear.theme_type_variation = &"GoldText"
		from_gear.custom_minimum_size = Vector2(44, 0)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		line.add_child(name_label)
		line.add_child(value)
		line.add_child(from_gear)
		var bar := ProgressBar.new()
		bar.theme_type_variation = &"GoldBar"
		bar.show_percentage = false
		bar.max_value = STAT_BAR_FULL
		bar.custom_minimum_size = Vector2(0, 22)
		var own := ProgressBar.new()
		own.theme_type_variation = &"OwnBarOverlay"
		own.show_percentage = false
		own.max_value = STAT_BAR_FULL
		bar.add_child(own)
		own.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_bars[stat] = bar
		_own_bars[stat] = own
		_values[stat] = value
		_gear_values[stat] = from_gear
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 6)
		cell.add_child(line)
		cell.add_child(bar)
		grid.add_child(cell)
	_health = health_row()
	_details.add_sibling(_health)
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


## Landscape sets the card and the gear side by side: the card stacks its figure, name and status,
## and its training XP and Stop, and the gear's cells are as narrow as their boxes. Portrait stacks
## the two. The gear goes four to a row either way.
func set_landscape(landscape: bool) -> void:
	_landscape = landscape
	($Box/Scroll/Content as BoxContainer).vertical = not landscape
	($Box/Scroll/Content/Card/Header/Row as BoxContainer).vertical = landscape
	($Box/Scroll/Content/Card/Header/Row/Words/NameLine as BoxContainer).vertical = landscape
	($Box/Scroll/Content/Card/Header/Row/Words/Training as BoxContainer).vertical = landscape
	# The card is too narrow in landscape for the health text's fixed width to leave room for a bar.
	(_health.get_child(1) as Control).custom_minimum_size.x = 0.0 if landscape else HEALTH_TEXT_WIDTH_PX
	if not _gear_shown.is_empty():
		_show_gear(_gear_shown[1])


## Shows `adventurer` as `dispatch` has them at `now`: Promote once they reach the level their next
## rank needs, disabled with the reason when `gold` is short or they are out; Train only when one of
## `training_places` would take them now; Dismiss while they are home and not the last, disabled with
## the reason while something else keeps them.
func show_adventurer(adventurer: String, dispatch: Dispatch, gold: Gold, training_places: int, now: int) -> void:
	_adventurer = adventurer
	var adventurers := dispatch.adventurers
	var info: Dictionary = adventurers.roster[adventurer]
	_figure.texture = QuestBoard.figure(Faces.seed_of(adventurer, info), adventurers.gear.worn[adventurer])
	var level: int = adventurers.levels[adventurer]
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
	_xp_text.text = xp_line(xp, needed, level + 1)
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
	_training_notes.text = "Grows fastest in " + hint
	_training_notes.visible = not hint.is_empty()
	for stat: String in Adventurers.STATS:
		var total := adventurers.stat_total(adventurer, stat)
		var from_gear := adventurers.gear.bonus(adventurer, stat)
		_bars[stat].value = total
		_own_bars[stat].value = total - from_gear
		_values[stat].text = str(total)
		_gear_values[stat].text = "+%d" % from_gear if from_gear > 0 else ""
	var history: Array = adventurers.history[adventurer]
	if history != _history_shown:
		_history_shown = history.duplicate(true)
		for line: Node in _history.get_children():
			line.queue_free()
		for i: int in range(history.size() - 1, -1, -1):
			var line := Label.new()
			line.text = _history_line(history[i])
			line.theme_type_variation = &"Secondary"
			_history.add_child(line)
	var gear_shown := [adventurer, adventurers.gear.worn[adventurer].duplicate()]
	if gear_shown != _gear_shown:
		_gear_shown = gear_shown
		_show_gear(gear_shown[1])


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


# The eight slots: each item's icon, the slot, its name and bonus; an empty slot dashed. A tap
# anywhere on a slot, box or words, opens it.
func _show_gear(worn: Dictionary) -> void:
	for cell: Node in _gear.get_children():
		cell.queue_free()
	for slot: String in Gear.SLOTS:
		var item: String = worn.get(slot, "")
		var box := PanelContainer.new()
		box.custom_minimum_size = Vector2(172, 172)
		box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var slot_name := Label.new()
		slot_name.text = Gear.SLOTS[slot].to_upper()
		slot_name.theme_type_variation = &"Caption"
		var cell := VBoxContainer.new()
		cell.custom_minimum_size = Vector2(0 if _landscape else 228, 0)
		cell.add_theme_constant_override("separation", 6)
		cell.add_child(box)
		cell.add_child(slot_name)
		if item.is_empty():
			box.theme_type_variation = &"ItemBoxEmpty"
			box.draw.connect(_draw_dashed_box.bind(box))
			var empty := Label.new()
			empty.text = "Empty"
			empty.theme_type_variation = &"Caption"
			cell.add_child(empty)
		else:
			box.theme_type_variation = &"ItemBox"
			box.add_child(item_icon(item, 5))
			cell.add_child(item_name(item))
			var bonus := bonus_label(item)
			# Landscape's narrow cells fit a stat's name whole only in smaller type.
			if _landscape:
				bonus.add_theme_font_size_override(&"font_size", LANDSCAPE_BONUS_FONT_PX)
			cell.add_child(bonus)
		for label: Node in cell.get_children():
			if label is Label:
				(label as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# A MarginContainer stacks its children, so the button covers the whole cell and the cell
		# sets the size.
		var open := Button.new()
		open.flat = true
		open.pressed.connect(slot_pressed.emit.bind(_adventurer, slot))
		var stack := MarginContainer.new()
		stack.add_child(cell)
		stack.add_child(open)
		_gear.add_child(stack)


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
