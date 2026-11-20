class_name HallView
extends Control

## The player asked to restore the damaged room `slot`.
signal restore_pressed(slot: String)
## The player asked to give the empty room `slot` a job.
signal job_pressed(slot: String)
## The player asked to send someone ready on a quest.
signal send_pressed
## The player asked to collect the gold in the Tavern `slot`.
signal collect_pressed(slot: String)
## The player asked to extend the hall with the First floor.
signal extend_pressed

## How a room is drawn on the plan.
enum Look { IN_USE, CONVERTED, INFIRMARY, EMPTY, DAMAGED, RESTORING, CONVERTING }

# The Ground floor seen from above, as fractions of the plan: y = 0 is the back wall, y = 1 the
# front, at the bottom of the screen.
const GROUND_FLOOR: Dictionary[String, Rect2] = {
	"back_left": Rect2(0.0, 0.0, 0.5, 0.3),
	"back_right": Rect2(0.5, 0.0, 0.5, 0.3),
	"side_left": Rect2(0.0, 0.3, 0.3, 0.4),
	"reception": Rect2(0.3, 0.3, 0.4, 0.4),
	"side_right": Rect2(0.7, 0.3, 0.3, 0.4),
	"entrance": Rect2(0.0, 0.7, 1.0, 0.3),
}
# The First floor the same way: four rooms, and at the front the landing the stairs come up to,
# which is not a room.
const FIRST_FLOOR: Dictionary[String, Rect2] = {
	"upper_nw": Rect2(0.0, 0.0, 0.5, 0.4),
	"upper_ne": Rect2(0.5, 0.0, 0.5, 0.4),
	"upper_sw": Rect2(0.0, 0.4, 0.5, 0.4),
	"upper_se": Rect2(0.5, 0.4, 0.5, 0.4),
}
const LANDING: Rect2 = Rect2(0.0, 0.8, 1.0, 0.2)
## The room the stairs to the First floor go up from, where the hall is extended.
const STAIRS: String = "entrance"
## A slot's name until it is given a job: where it is, or what it was built as.
const SLOT_NAMES: Dictionary[String, String] = {
	"back_left": "North-west room",
	"back_right": "North-east room",
	"side_left": "West room",
	"side_right": "East room",
	"upper_nw": "Upper north-west room",
	"upper_ne": "Upper north-east room",
	"upper_sw": "Upper south-west room",
	"upper_se": "Upper south-east room",
	"entrance": "Entrance hall",
	"reception": "Reception",
}
## What the rooms usable from the start are for.
const USABLE_LINES: Dictionary[String, String] = {"entrance": "Staircase closed", "reception": "Ranks, quest intake"}

const ROOM_GAP_PX: float = 4.0
const ROOM_PADDING_PX: int = 22
const BORDER_PX: float = 3.0
const DASH_PX: float = 12.0
const HATCH_STRIPE_PX: float = 17.0
const HATCH_DARK: Color = Color("#221c28")
const HATCH_LIGHT: Color = Color("#2b2431")
const IN_USE_FILL: Color = Color("#2a2533")
const IN_USE_BORDER: Color = Color("#4a4258")
const GOLD: Color = Color("#f2c14e")
const GREEN: Color = Color("#6fcf8e")
const EMPTY_BORDER: Color = Color("#8a7a4a")
const DAMAGED_BORDER: Color = Color("#5a5068")
const RESTORING_BORDER: Color = Color("#4a6a88")

var _rooms: Dictionary[String, Room] = {}
## What the In progress rows show apart from their times, so the list is rebuilt only when that
## changes; `_rows` are its timed rows, in the same order.
var _entries: Array[Dictionary] = []
var _rows: Array[Row] = []
## Each floor's rooms, shown one floor at a time, and how many of them are in use.
var _ground: Control
var _upstairs: Control
var _ground_in_use: int = 0
var _upstairs_in_use: int = 0

@onready var _summary: Label = $Scroll/Box/Top/Header/Summary
@onready var _parties: Control = $Scroll/Box/Top/Header/Parties
@onready var _parties_count: Label = $Scroll/Box/Top/Header/Parties/Count
@onready var _first_button: Button = $Scroll/Box/Top/Floors/Row/First
@onready var _plan: Control = $Scroll/Box/Columns/Left/Plan
@onready var _legend: HBoxContainer = $Scroll/Box/Columns/Left/Legend
@onready var _section: Control = $Scroll/Box/Columns/Right/Section
@onready var _list: Control = $Scroll/Box/Columns/Right/List
@onready var _list_rows: VBoxContainer = $Scroll/Box/Columns/Right/List/Rows


## A room on the plan and the parts that change with its state.
class Room extends Control:
	var look: int = -1
	var title: Label
	var line: Label
	var tokens: HFlowContainer
	## The [adventurer, injured] pairs shown in `tokens`, so they are rebuilt only when they change.
	var shown: Array = []
	var restore_row: HFlowContainer
	## What the next restoration costs and takes.
	var restore_cost: Label
	var restore: Button
	var reason: Label
	var job: Button
	var countdown: Label
	var bar: ProgressBar
	var collect: Button


## An In progress row's parts that change each second.
class Row extends RefCounted:
	var bar: ProgressBar
	var time: Label


func _ready() -> void:
	_ground = _add_floor()
	_upstairs = _add_floor()
	_upstairs.visible = false
	for slot: String in GROUND_FLOOR:
		_add_room(slot, GROUND_FLOOR[slot], _ground)
	for slot: String in FIRST_FLOOR:
		_add_room(slot, FIRST_FLOOR[slot], _upstairs)
	_add_landing()
	# The floor buttons are a group, so pressing Ground untoggles 1F.
	_first_button.toggled.connect(_on_first_toggled)
	var dot := Panel.new()
	dot.theme_type_variation = &"InjuredDot"
	dot.custom_minimum_size = Vector2(24, 24)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var entries: Array[Array] = [[_swatch(Look.IN_USE, Vector2(30, 30)), "In use"], [_swatch(Look.EMPTY, Vector2(30, 30)), "Empty"], [_swatch(Look.DAMAGED, Vector2(30, 30)), "Damaged"], [dot, "Injured"]]
	for entry: Array in entries:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 12)
		item.add_child(entry[0])
		var text := _label(entry[1], &"Secondary")
		text.autowrap_mode = TextServer.AUTOWRAP_OFF
		item.add_child(text)
		_legend.add_child(item)


## Landscape puts the floor bar beside the header and In progress beside the plan, shows how many
## parties are out in the header, and leaves out the legend; portrait stacks them all.
func set_landscape(landscape: bool) -> void:
	($Scroll/Box/Top as BoxContainer).vertical = not landscape
	($Scroll/Box/Columns as BoxContainer).vertical = not landscape
	_parties.visible = landscape
	_legend.visible = not landscape


## Shows the hall, who is home, and what is under way at `now`; `quests_on_board` is how many
## quests the board offers.
func show_state(hall: Hall, dispatch: Dispatch, gold: Gold, quests_on_board: int, now: int) -> void:
	_ground_in_use = 0
	_upstairs_in_use = 0
	for slot: String in _rooms:
		var state := hall.state(slot, now)
		if state == Hall.State.USABLE or state == Hall.State.CONVERTED:
			if slot in FIRST_FLOOR:
				_upstairs_in_use += 1
			else:
				_ground_in_use += 1
		_show_room(_rooms[slot], slot, state, hall, gold, now)
	# Injured adventurers rest in the Infirmary that heals them: the first one finished.
	var infirmary := hall.first_room("infirmary")
	if not infirmary.is_empty() and hall.state(infirmary, now) != Hall.State.CONVERTED:
		infirmary = ""
	_first_button.disabled = not hall.has_first_floor(now)
	_show_summary()
	_parties_count.text = str(dispatch.outings.size())
	_show_tokens(dispatch, infirmary, now)
	_show_progress(hall, dispatch, quests_on_board, now)


func _on_first_toggled(upstairs: bool) -> void:
	_ground.visible = not upstairs
	_upstairs.visible = upstairs
	_show_summary()


func _show_summary() -> void:
	if _upstairs.visible:
		_summary.text = "First floor · %d of %d rooms in use" % [_upstairs_in_use, FIRST_FLOOR.size()]
	else:
		_summary.text = "Ground floor · %d of %d rooms in use" % [_ground_in_use, GROUND_FLOOR.size()]


func _show_room(room: Room, slot: String, state: Hall.State, hall: Hall, gold: Gold, now: int) -> void:
	var type := hall.room_type(slot)
	var held := hall.tavern_gold(slot, now)
	var look := Look.IN_USE
	var building := state == Hall.State.RESTORING or state == Hall.State.CONVERTING
	var offered := state == Hall.State.DAMAGED
	room.title.text = SLOT_NAMES[slot]
	room.line.theme_type_variation = &"Secondary"
	match state:
		Hall.State.USABLE:
			room.line.text = USABLE_LINES[slot]
			if slot == STAIRS and hall.has_first_floor(now):
				room.line.text = "Stairs to 1F"
			elif slot == STAIRS and hall.building == Hall.EXTENSION:
				room.line.text = "Building the first floor"
				room.line.theme_type_variation = &"BuildText"
				room.bar.theme_type_variation = &"BuildBar"
				room.bar.max_value = Hall.EXTEND_SECONDS
				building = true
			elif slot == STAIRS:
				_offer(room, "%dg · %s" % [Hall.EXTEND_GOLD, Duration.label(Hall.EXTEND_SECONDS)], hall.extend_refusal(gold, now))
				offered = true
		Hall.State.CONVERTED:
			var info: Dictionary = Hall.ROOM_TYPES[type]
			var blurb: String = info["blurb"]
			room.title.text = info["name"]
			room.line.text = blurb.left(1).to_upper() + blurb.substr(1)
			if type == "tavern":
				_show_tavern(room, held)
			look = Look.INFIRMARY if type == "infirmary" else Look.CONVERTED
		Hall.State.RESTORED:
			room.line.text = "Empty"
			look = Look.EMPTY
		Hall.State.DAMAGED:
			room.line.text = "Damaged"
			var next := hall.next_restore()
			_offer(room, "%dg · %s" % [next["gold"], Duration.label(next["seconds"])], hall.refusal(slot, gold, now))
			look = Look.DAMAGED
		Hall.State.RESTORING:
			room.line.text = "Restoring"
			room.line.theme_type_variation = &"BuildText"
			room.bar.theme_type_variation = &"BuildBar"
			room.bar.max_value = hall.job_seconds()
			look = Look.RESTORING
		Hall.State.CONVERTING:
			room.line.text = "Converting to %s" % Hall.ROOM_TYPES[type]["name"]
			room.line.theme_type_variation = &"GoldText"
			room.bar.theme_type_variation = &"GoldBar"
			room.bar.max_value = Hall.ROOM_TYPES[type]["seconds"]
			look = Look.CONVERTING
	if building:
		var left := hall.seconds_left(now)
		room.countdown.text = Duration.label(left)
		room.bar.value = room.bar.max_value - left
	var tavern := state == Hall.State.CONVERTED and type == "tavern"
	room.countdown.visible = building
	room.bar.visible = building or tavern
	room.collect.visible = held > 0
	room.restore_row.visible = offered
	room.job.visible = state == Hall.State.RESTORED
	if look != room.look:
		room.look = look
		room.queue_redraw()


# A room's action row: what it costs and takes, and why it can't be done when it can't.
func _offer(room: Room, cost: String, reason: String) -> void:
	room.restore_cost.text = cost
	room.restore.disabled = not reason.is_empty()
	room.reason.text = reason
	room.reason.visible = not reason.is_empty()


# A Tavern's fill, which stands out in gold once full.
func _show_tavern(room: Room, held: int) -> void:
	var full := held == Hall.TAVERN_CAP
	room.line.text = "Full — collect" if full else "%d / %dg" % [held, Hall.TAVERN_CAP]
	room.line.theme_type_variation = &"GoldText" if full else &"Secondary"
	room.bar.theme_type_variation = &"GoldBar"
	room.bar.max_value = Hall.TAVERN_CAP
	room.bar.value = held


## Where the room `slot` is on screen, at its centre, for effects drawn over the hall.
func room_center(slot: String) -> Vector2:
	return _rooms[slot].get_global_rect().get_center()


# Adventurers at home: an injured one rests in the first finished Infirmary, or in Reception when
# there is none; a ready one waits in Reception.
func _show_tokens(dispatch: Dispatch, infirmary: String, now: int) -> void:
	var people: Dictionary[String, Array] = {}
	var roster := dispatch.adventurers.roster
	for adventurer: String in roster:
		if not dispatch.quest_of(adventurer).is_empty():
			continue
		var injured := dispatch.injury_left(adventurer, now) > 0
		var slot := infirmary if injured and not infirmary.is_empty() else "reception"
		if not people.has(slot):
			people[slot] = []
		people[slot].append([adventurer, injured])
	for slot: String in _rooms:
		var room := _rooms[slot]
		var shown: Array = people.get(slot, [])
		if shown == room.shown:
			continue
		room.shown = shown
		for token: Node in room.tokens.get_children():
			token.queue_free()
		for person: Array in shown:
			room.tokens.add_child(_token(person[0], person[1], roster))
		room.tokens.visible = not shown.is_empty()


# Timed rows first, each with its total and seconds left; progress is how much of the total has
# passed. The Send row comes last.
func _show_progress(hall: Hall, dispatch: Dispatch, quests_on_board: int, now: int) -> void:
	var entries: Array[Dictionary] = []
	var waits: Array[Vector2i] = []
	for outing: Dictionary in dispatch.outings:
		var quest: Dictionary = Dispatch.QUESTS[outing["quest"]]
		entries.append({"tokens": outing["party"], "title": quest["name"], "bar": &"GoldBar"})
		waits.append(Vector2i(quest["seconds"], dispatch.seconds_left(outing, now)))
	var build_left := hall.seconds_left(now)
	if build_left > 0:
		if hall.building == Hall.EXTENSION:
			entries.append({"swatch": Look.RESTORING, "title": "Building the first floor", "bar": &"BuildBar"})
		elif hall.building_into.is_empty():
			entries.append({"swatch": Look.RESTORING, "title": "Restoring the " + SLOT_NAMES[hall.building].to_lower(), "bar": &"BuildBar"})
		else:
			entries.append({"swatch": Look.CONVERTING, "title": "Converting the " + SLOT_NAMES[hall.building].to_lower(), "bar": &"GoldBar"})
		waits.append(Vector2i(hall.job_seconds(), build_left))
	var at_hand := PackedStringArray()
	var roster := dispatch.adventurers.roster
	for adventurer: String in roster:
		var injury_left := dispatch.injury_left(adventurer, now)
		if injury_left > 0:
			var healing: String = roster[adventurer]["name"]
			entries.append({"tokens": [adventurer], "injured": true, "title": healing + " is healing", "bar": &"InjuryBar"})
			waits.append(Vector2i(dispatch.injury_seconds(adventurer), injury_left))
		elif dispatch.can_go(adventurer, now):
			at_hand.append(adventurer)
	if not at_hand.is_empty() and quests_on_board > 0:
		# One ready shows their initial and name, several show how many.
		var one := at_hand.size() == 1
		entries.append({
			"tokens": [at_hand[0] if one else str(at_hand.size())],
			"title": "%s ready" % (roster[at_hand[0]]["name"] + " is" if one else str(at_hand.size())),
			"sub": "%d quest%s on the board" % [quests_on_board, "" if quests_on_board == 1 else "s"],
		})
	if entries != _entries:
		_entries = entries
		_rebuild_rows(roster)
	for i: int in waits.size():
		_rows[i].bar.max_value = waits[i].x
		_rows[i].bar.value = waits[i].x - waits[i].y
		_rows[i].time.text = Duration.label(waits[i].y)
	_section.visible = not entries.is_empty()
	_list.visible = not entries.is_empty()


func _rebuild_rows(roster: Dictionary) -> void:
	for row: Node in _list_rows.get_children():
		row.queue_free()
	_rows.clear()
	for entry: Dictionary in _entries:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 32)
		if entry.has("swatch"):
			line.add_child(_swatch(entry["swatch"], Vector2(80, 80)))
		else:
			var stack := HBoxContainer.new()
			stack.theme_type_variation = &"TokenStack"
			for who: String in entry["tokens"]:
				stack.add_child(_token(who, entry.get("injured", false), roster))
			line.add_child(stack)
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		words.add_child(_label(entry["title"], &"RowTitle"))
		line.add_child(words)
		if entry.has("bar"):
			var row := Row.new()
			row.bar = _bar(entry["bar"])
			words.add_child(row.bar)
			row.time = _label("", &"Numbers")
			row.time.autowrap_mode = TextServer.AUTOWRAP_OFF
			line.add_child(row.time)
			_rows.append(row)
		else:
			words.add_child(_label(entry["sub"], &"Secondary"))
			var go := Button.new()
			go.text = "Send →"
			go.theme_type_variation = &"GoldLink"
			go.pressed.connect(send_pressed.emit)
			line.add_child(go)
		var panel := PanelContainer.new()
		panel.theme_type_variation = &"ProgressRow"
		panel.add_child(line)
		_list_rows.add_child(panel)


# A floor's layer over the whole plan, for its rooms.
func _add_floor() -> Control:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_PASS
	_plan.add_child(layer)
	return layer


# Puts `item` on `layer` over `area`, a fraction of the plan, a gap in from its edges.
func _lay(item: Control, area: Rect2, layer: Control) -> void:
	item.clip_contents = true
	item.anchor_left = area.position.x
	item.anchor_top = area.position.y
	item.anchor_right = area.end.x
	item.anchor_bottom = area.end.y
	item.offset_left = ROOM_GAP_PX
	item.offset_top = ROOM_GAP_PX
	item.offset_right = -ROOM_GAP_PX
	item.offset_bottom = -ROOM_GAP_PX
	layer.add_child(item)


# The First floor's landing: drawn as a room in use, with nothing to do there.
func _add_landing() -> void:
	var landing := Control.new()
	landing.draw.connect(_paint.bind(landing, Look.IN_USE))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, ROOM_PADDING_PX)
	box.add_child(_label("Landing", &"RoomName"))
	box.add_child(_label("Stairs down to the Entrance hall", &"Secondary"))
	landing.add_child(box)
	_lay(landing, LANDING, _upstairs)


func _add_room(slot: String, area: Rect2, layer: Control) -> void:
	var room := Room.new()
	room.draw.connect(func() -> void: _paint(room, room.look))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, ROOM_PADDING_PX)
	room.add_child(box)
	room.title = _label("", &"RoomName")
	room.line = _label("", &"Secondary")
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	room.tokens = HFlowContainer.new()
	room.tokens.visible = false
	room.restore_row = HFlowContainer.new()
	room.restore_row.add_theme_constant_override("h_separation", 16)
	room.restore_cost = _label("", &"Meta")
	room.restore_cost.autowrap_mode = TextServer.AUTOWRAP_OFF
	room.restore_row.add_child(room.restore_cost)
	room.restore = Button.new()
	room.restore.theme_type_variation = &"RestoreButton"
	if slot == STAIRS:
		room.restore.text = "Extend · 1F"
		room.restore.pressed.connect(extend_pressed.emit)
	else:
		room.restore.text = "Restore"
		room.restore.pressed.connect(restore_pressed.emit.bind(slot))
	room.restore_row.add_child(room.restore)
	room.reason = _label("", &"RoomAlert")
	room.reason.autowrap_mode = TextServer.AUTOWRAP_OFF
	room.restore_row.add_child(room.reason)
	room.job = Button.new()
	room.job.text = "+ Give it a job"
	room.job.theme_type_variation = &"GoldLink"
	room.job.alignment = HORIZONTAL_ALIGNMENT_LEFT
	room.job.pressed.connect(job_pressed.emit.bind(slot))
	room.countdown = _label("", &"Countdown")
	room.bar = _bar(&"BuildBar")
	room.collect = Button.new()
	room.collect.text = "Collect"
	room.collect.theme_type_variation = &"GoldButton"
	room.collect.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	room.collect.pressed.connect(collect_pressed.emit.bind(slot))
	for part: Control in [room.title, room.line, spacer, room.tokens, room.restore_row, room.job, room.countdown, room.bar, room.collect]:
		box.add_child(part)
	_lay(room, area, layer)
	_rooms[slot] = room


func _paint(item: Control, look: int) -> void:
	var area := Rect2(Vector2.ZERO, item.size)
	var edge := area.grow(-BORDER_PX / 2.0)
	match look:
		Look.IN_USE:
			item.draw_rect(area, IN_USE_FILL)
			item.draw_rect(edge, IN_USE_BORDER, false, BORDER_PX)
		Look.CONVERTED:
			item.draw_rect(area, Color(GOLD, 0.10))
			item.draw_rect(edge, Color(GOLD, 0.55), false, BORDER_PX)
		Look.INFIRMARY:
			item.draw_rect(area, Color(GREEN, 0.08))
			item.draw_rect(edge, Color(GREEN, 0.5), false, BORDER_PX)
		Look.EMPTY:
			_dash(item, edge, EMPTY_BORDER)
		Look.DAMAGED:
			_hatch(item, area)
			_dash(item, edge, DAMAGED_BORDER)
		Look.RESTORING:
			_hatch(item, area)
			item.draw_rect(edge, RESTORING_BORDER, false, BORDER_PX)
		Look.CONVERTING:
			item.draw_rect(edge, Color(GOLD, 0.55), false, BORDER_PX)


# Diagonal stripes rising to the right; `item` clips what runs past its edges.
func _hatch(item: Control, area: Rect2) -> void:
	item.draw_rect(area, HATCH_DARK)
	var height := area.size.y
	var step := HATCH_STRIPE_PX * 2.0 * sqrt(2.0)
	var x := -height - HATCH_STRIPE_PX
	while x < area.size.x + HATCH_STRIPE_PX:
		item.draw_line(Vector2(x - HATCH_STRIPE_PX, height + HATCH_STRIPE_PX), Vector2(x + height + HATCH_STRIPE_PX, -HATCH_STRIPE_PX), HATCH_LIGHT, HATCH_STRIPE_PX)
		x += step


func _dash(item: Control, edge: Rect2, color: Color) -> void:
	var corners: Array[Vector2] = [edge.position, Vector2(edge.end.x, edge.position.y), edge.end, Vector2(edge.position.x, edge.end.y)]
	for i: int in corners.size():
		item.draw_dashed_line(corners[i], corners[(i + 1) % corners.size()], color, BORDER_PX, DASH_PX)


func _swatch(look: Look, size_px: Vector2) -> Control:
	var swatch := Control.new()
	swatch.custom_minimum_size = size_px
	swatch.clip_contents = true
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.draw.connect(_paint.bind(swatch, look))
	return swatch


# An adventurer's face, or a count as text, marked with a dot when injured.
func _token(who: String, injured: bool, roster: Dictionary) -> Label:
	var token := QuestBoard.token(who, roster)
	if injured:
		var dot := Panel.new()
		dot.theme_type_variation = &"InjuredDot"
		dot.size = Vector2(26, 26)
		dot.position = Vector2(56, -2)
		token.add_child(dot)
	return token


func _bar(variation: StringName) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.theme_type_variation = variation
	bar.show_percentage = false
	bar.step = 1.0
	bar.custom_minimum_size = Vector2(0, 12)
	return bar


func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.theme_type_variation = variation
	return label
