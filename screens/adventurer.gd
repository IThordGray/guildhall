class_name Adventurer
extends Control

## The player is done looking at this adventurer.
signal back_pressed
## The player chose to level up `adventurer`, a key of Adventurers.roster.
signal level_up_pressed(adventurer: String)
## The player chose to put the stash item at `index` on `adventurer`.
signal wear_pressed(adventurer: String, index: int)
## The player swiped to the next adventurer in roster order (`step` 1) or the previous (`step` -1).
signal swiped(step: int)

## A stat at this value fills its bar.
const STAT_BAR_FULL: int = 20
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
## The adventurer, their gear, the stash and whether they may change gear, as shown, so the gear
## and stash are rebuilt only when these change.
var _gear_shown: Array = []
## Whether the landscape layout shows, so the gear and stash are built to fit its narrower columns.
var _landscape: bool = false
## Whether a press that started on this screen is held, so its release may be a swipe.
var _press_held: bool = false
## Where the held press started, in viewport pixels.
var _press_at: Vector2 = Vector2.ZERO
## The button the held press started on, if any.
var _press_button: BaseButton = null

@onready var _token: Label = $Box/Scroll/Content/Card/Header/Row/Token
@onready var _name: Label = $Box/Scroll/Content/Card/Header/Row/Words/NameLine/Name
@onready var _status: Label = $Box/Scroll/Content/Card/Header/Row/Words/NameLine/Status
@onready var _details: Label = $Box/Scroll/Content/Card/Header/Row/Words/Details
@onready var _level_up: Button = $Box/Scroll/Content/Card/Header/Row/Words/LevelUp
@onready var _xp: VBoxContainer = $Box/Scroll/Content/Card/Header/Row/Words/Xp
@onready var _xp_bar: ProgressBar = $Box/Scroll/Content/Card/Header/Row/Words/Xp/Bar
@onready var _xp_text: Label = $Box/Scroll/Content/Card/Header/Row/Words/Xp/Text
@onready var _history: VBoxContainer = $Box/Scroll/Content/Card/Stats/Rows/History
@onready var _gear: GridContainer = $Box/Scroll/Content/GearColumn/Gear
@onready var _stash_section: Label = $Box/Scroll/Content/StashColumn/StashSection
@onready var _stash: VBoxContainer = $Box/Scroll/Content/StashColumn/Stash/Items


func _ready() -> void:
	var rows := $Box/Scroll/Content/Card/Stats/Rows as VBoxContainer
	for stat: String in Adventurers.STATS:
		var row := stat_row(Adventurers.STATS[stat], &"Label")
		var bar: ProgressBar = row.get_child(1)
		bar.theme_type_variation = &"GoldBar"
		var own := ProgressBar.new()
		own.theme_type_variation = &"OwnBarOverlay"
		own.show_percentage = false
		own.max_value = STAT_BAR_FULL
		bar.add_child(own)
		own.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_bars[stat] = bar
		_own_bars[stat] = own
		_values[stat] = row.get_child(2)
		var from_gear := Label.new()
		from_gear.theme_type_variation = &"GoldText"
		from_gear.custom_minimum_size = Vector2(70, 0)
		row.add_child(from_gear)
		_gear_values[stat] = from_gear
		rows.add_child(row)
		rows.move_child(row, _bars.size() - 1)
	_health = health_row()
	_details.add_sibling(_health)
	_level_up.pressed.connect(func() -> void: level_up_pressed.emit(_adventurer))
	($Box/Back as Button).pressed.connect(back_pressed.emit)


# Watched here, not in _gui_input: the scroll container and the buttons take the drags and presses
# first. Nothing is marked handled, so they still get every event. Only mouse events are read: touch
# arrives as the mouse events Godot emulates from it (on by default), the same ones buttons press on,
# so a swipe counts once.
func _input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT or not is_visible_in_tree():
		return
	var hovered := get_viewport().gui_get_hovered_control()
	if click.pressed:
		_press_held = get_global_rect().has_point(click.position)
		_press_at = click.position
		_press_button = hovered as BaseButton
		return
	var held := _press_held
	_press_held = false
	if not held or click.canceled:
		return
	# A release on the button the press started on presses it, so it is not also a swipe.
	if hovered != null and hovered == _press_button:
		return
	var travel := click.position - _press_at
	if absf(travel.x) >= SWIPE_MIN_PX and absf(travel.x) > absf(travel.y):
		# Swiping left brings the next adventurer in, as turning a page does.
		swiped.emit(1 if travel.x < 0 else -1)


## Landscape sets the card, the gear and the stash side by side: the card stacks its face, name
## and status, the gear goes two to a row, as narrow as its boxes, and Wear buttons wrap. Portrait
## stacks the three, the gear four to a row.
func set_landscape(landscape: bool) -> void:
	_landscape = landscape
	($Box/Scroll/Content as BoxContainer).vertical = not landscape
	($Box/Scroll/Content/Card/Header/Row as BoxContainer).vertical = landscape
	($Box/Scroll/Content/Card/Header/Row/Words/NameLine as BoxContainer).vertical = landscape
	_gear.columns = 2 if landscape else 4
	# The card is too narrow in landscape for the health text's fixed width to leave room for a bar.
	(_health.get_child(1) as Control).custom_minimum_size.x = 0.0 if landscape else HEALTH_TEXT_WIDTH_PX
	if not _gear_shown.is_empty():
		_show_gear(_gear_shown[1])
		_show_stash(_gear_shown[2], _gear_shown[3])


## Shows `adventurer` as `dispatch` has them at `now`.
func show_adventurer(adventurer: String, dispatch: Dispatch, now: int) -> void:
	if adventurer != _adventurer:
		var token := QuestBoard.token(adventurer, dispatch.adventurers.roster)
		token.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		# Not replace_by: it would move the old token's face onto the new one.
		_token.add_sibling(token)
		_token.get_parent().remove_child(_token)
		_token.queue_free()
		_token = token
	_adventurer = adventurer
	var adventurers := dispatch.adventurers
	var info: Dictionary = adventurers.roster[adventurer]
	var level: int = adventurers.levels[adventurer]
	_name.text = info["name"]
	_status.text = dispatch.status(adventurer, now)
	_status.theme_type_variation = Roster.status_look(dispatch, adventurer, now)
	_details.text = "%s · rank %s · level %d" % [info["class"], info["rank"], level]
	show_health(_health, adventurer, dispatch, now)
	var xp: int = adventurers.xp[adventurer]
	var needed := adventurers.xp_needed(adventurer)
	_level_up.visible = adventurers.level_up_ready(adventurer)
	_level_up.text = "Level up · XP %d / %d" % [xp, needed]
	_xp.visible = not _level_up.visible
	_xp_bar.max_value = needed
	_xp_bar.value = xp
	_xp_text.text = xp_line(xp, needed, level + 1)
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
	var gear := adventurers.gear
	var can_change := dispatch.can_change_gear(adventurer)
	var gear_shown := [adventurer, gear.worn[adventurer].duplicate(), gear.stash.duplicate(), can_change]
	if gear_shown != _gear_shown:
		_gear_shown = gear_shown
		_show_gear(gear.worn[adventurer])
		_show_stash(gear.stash, can_change)


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


# What `item` adds, "Might +3 · Grit +4", in gold; "none" when nothing.
static func _bonus_label(item: String) -> Label:
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


# The eight slots: each item's icon, the slot, its name and bonus; an empty slot dashed.
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
			cell.add_child(_bonus_label(item))
		for label: Node in cell.get_children():
			if label is Label:
				(label as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_gear.add_child(cell)


# The stash, each item with a Wear button, disabled while this adventurer is out.
func _show_stash(stash: PackedStringArray, can_change: bool) -> void:
	_stash_section.text = "STASH · %d / %d" % [stash.size(), Gear.STASH_CAP]
	for row: Node in _stash.get_children():
		row.queue_free()
	if stash.is_empty():
		var empty := Label.new()
		empty.text = "Empty. Some quests bring back items."
		empty.theme_type_variation = &"Caption"
		var row := PanelContainer.new()
		row.theme_type_variation = &"ProgressRow"
		row.add_child(empty)
		_stash.add_child(row)
	for i: int in stash.size():
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		words.add_child(item_name(stash[i]))
		words.add_child(_bonus_label(stash[i]))
		var wear := Button.new()
		wear.text = "Wear" if can_change else "Out on a quest"
		wear.disabled = not can_change
		wear.custom_minimum_size = Vector2(200, 100)
		wear.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if _landscape else TextServer.AUTOWRAP_OFF
		wear.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		wear.pressed.connect(func() -> void: wear_pressed.emit(_adventurer, i))
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 32)
		line.add_child(item_icon(stash[i], 3))
		line.add_child(words)
		line.add_child(wear)
		var row := PanelContainer.new()
		row.theme_type_variation = &"ProgressRow"
		row.add_child(line)
		_stash.add_child(row)


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
	name_label.custom_minimum_size = Vector2(190, 0)
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


# "Level 3 · Might +1 · Grit +2", naming only the stats that rose.
func _history_line(entry: Dictionary) -> String:
	var parts := PackedStringArray(["Level %d" % entry["level"]])
	for stat: String in Adventurers.STATS:
		var gain: int = entry["gains"].get(stat, 0)
		if gain > 0:
			parts.append("%s +%d" % [Adventurers.STATS[stat], gain])
	if parts.size() == 1:
		parts.append("no change")
	return " · ".join(parts)
