class_name HallView
extends Control

## The player tapped the damaged room `slot`, to restore it.
signal restore_pressed(slot: String)
## The player asked to give the empty room `slot` a job.
signal job_pressed(slot: String)
## The player asked to send someone ready on a quest.
signal send_pressed
## The player asked to collect the gold in the Tavern `slot`.
signal collect_pressed(slot: String)
## The player tapped the stairs, to extend the hall with the First floor.
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
	"back_left": "Backroom",
	"back_right": "North-east room",
	"side_left": "Side room",
	"side_right": "East room",
	"upper_nw": "Upper north-west room",
	"upper_ne": "Upper north-east room",
	"upper_sw": "Upper south-west room",
	"upper_se": "Upper south-east room",
	"entrance": "Entrance hall",
	"reception": "Reception",
}
## The names a hall saved before guild ranks keeps for its rooms where SLOT_NAMES differs.
const OLD_SLOT_NAMES: Dictionary[String, String] = {
	"back_left": "North-west room",
	"side_left": "West room",
}

const ROOM_GAP_PX: float = 4.0
const ROOM_PADDING_PX: int = 22
## Landscape rooms are narrower, so their padding shrinks to this to keep the longest name on one line.
const LANDSCAPE_ROOM_PADDING_PX: int = 12
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
## What a room's icon offers: a damaged room or the stairs to build, an empty room to give a job, a
## Tavern's gold to collect. Each a pixel image, a row of characters per line, coloured by
## ICON_COLORS; "." is see-through.
const ICONS: Dictionary[String, PackedStringArray] = {
	"build": [
		"......oo........",
		".....ohho.......",
		"....ohhhho......",
		"...ohhhhho......",
		"..ohhhhho.......",
		".ohhhhho........",
		"ohhhhhwwo.......",
		"ohhhhowwwo......",
		".ohho.owwwo.....",
		"..oo...owwwo....",
		"........owwwo...",
		".........owwwo..",
		"..........owwwo.",
		"...........owo..",
		"............o...",
		"................",
	],
	"job": [
		"................",
		"......oooo......",
		".....oggggo.....",
		".....oggggo.....",
		".....oggggo.....",
		"..ooooggggoooo..",
		".oggggggggggggo.",
		".oggggggggggggo.",
		".oggggggggggggo.",
		".oggggggggggggo.",
		"..ooooggggoooo..",
		".....oggggo.....",
		".....oggggo.....",
		".....oggggo.....",
		"......oooo......",
		"................",
	],
	"collect": [
		".......oo.......",
		"....oooddooo....",
		"...oddddddddo...",
		"..oddggggggddo..",
		".oddgglgggggddo.",
		".odgglgggggggdo.",
		".odgglgggggggdo.",
		"oddgglgggggggddo",
		"oddgglgggggggddo",
		".odggggggggggdo.",
		".odggggggggggdo.",
		".oddggggggggddo.",
		"..oddggggggddo..",
		"...oddddddddo...",
		"....oooddooo....",
		".......oo.......",
	],
}
const ICON_COLORS: Dictionary[String, Color] = {
	"o": Color("#16131b"),
	"h": Color("#cfc8dc"),
	"w": Color("#b07a42"),
	"g": Color("#f2c14e"),
	"d": Color("#c48a1e"),
	"l": Color("#fbe3a0"),
}
## How many screen pixels an icon's pixel takes; a whole number keeps its pixels square and sharp.
const ICON_SCALE: int = 6

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
var _ground_rooms: int = 0
## The guild's rank, shown in place of the floor's name when the hall has only one floor.
var _rank: String = ""
## Each room's and the landing's contents, padded in from its edges.
var _boxes: Array[Control] = []
## ICONS drawn once, by kind.
var _icons: Dictionary[String, Texture2D] = {}

@onready var _summary: Label = $Scroll/Box/Top/Header/Summary
@onready var _parties: Control = $Scroll/Box/Top/Header/Parties
@onready var _parties_count: Label = $Scroll/Box/Top/Header/Parties/Count
@onready var _floors: Control = $Scroll/Box/Top/Floors
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
	var tokens: HFlowContainer
	## The [adventurer, injured] pairs shown in `tokens`, so they are rebuilt only when they change.
	var shown: Array = []
	var bar: ProgressBar
	## What can be done here, centred on the room, as a key of ICONS; "" for nothing.
	var icon: TextureRect
	var kind: String = ""
	## What a tap anywhere on the room does: emits the signal for `kind`, or nothing.
	var action: Callable


## An In progress row's parts that change each second.
class Row extends RefCounted:
	var bar: ProgressBar
	var time: Label
	## The line under the title, for a row that has one.
	var line: Label


func _ready() -> void:
	for kind: String in ICONS:
		_icons[kind] = _pixel_image(ICONS[kind])
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
## parties are out in the header, and leaves out the legend; portrait stacks them all. In
## landscape the floor summary and room names keep to one line: the title is smaller, the header
## takes the width the summary needs from the floor bar, and rooms have less padding.
func set_landscape(landscape: bool) -> void:
	($Scroll/Box/Top as BoxContainer).vertical = not landscape
	($Scroll/Box/Columns as BoxContainer).vertical = not landscape
	_parties.visible = landscape
	_legend.visible = not landscape
	($Scroll/Box/Top/Header/Title as Label).theme_type_variation = &"Heading" if landscape else &"Title"
	_summary.autowrap_mode = TextServer.AUTOWRAP_OFF if landscape else TextServer.AUTOWRAP_WORD_SMART
	for box: Control in _boxes:
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, LANDSCAPE_ROOM_PADDING_PX if landscape else ROOM_PADDING_PX)


## Shows the hall, who is home, and what is under way at `now`; `quests_on_board` is how many
## quests the board offers.
func show_state(hall: Hall, dispatch: Dispatch, quests_on_board: int, now: int) -> void:
	_ground_in_use = 0
	_upstairs_in_use = 0
	_ground_rooms = 0
	for slot: String in _rooms:
		var state := hall.state(slot, now)
		# A ground-floor slot the hall doesn't have is left off the plan.
		_rooms[slot].visible = state != Hall.State.UNBUILT or slot in FIRST_FLOOR
		if slot not in FIRST_FLOOR and _rooms[slot].visible:
			_ground_rooms += 1
		if state == Hall.State.USABLE or state == Hall.State.CONVERTED:
			if slot in FIRST_FLOOR:
				_upstairs_in_use += 1
			else:
				_ground_in_use += 1
		_show_room(_rooms[slot], slot, state, hall, now)
	# Injured adventurers rest in the Infirmary that heals them: the first one finished.
	var infirmary := hall.first_room("infirmary")
	if not infirmary.is_empty() and hall.state(infirmary, now) != Hall.State.CONVERTED:
		infirmary = ""
	_first_button.disabled = not hall.has_first_floor(now)
	# Only a hall with stairs has floors to choose from.
	_floors.visible = hall.state(STAIRS, now) != Hall.State.UNBUILT
	_rank = hall.rank
	_show_summary()
	_parties_count.text = str(dispatch.outings.size())
	_show_tokens(hall, dispatch, infirmary, now)
	_show_progress(hall, dispatch, quests_on_board, now)


func _on_first_toggled(upstairs: bool) -> void:
	_ground.visible = not upstairs
	_upstairs.visible = upstairs
	_show_summary()


func _show_summary() -> void:
	if _upstairs.visible:
		_summary.text = "First floor · %d of %d rooms in use" % [_upstairs_in_use, FIRST_FLOOR.size()]
	elif _floors.visible:
		_summary.text = "Ground floor · %d of %d rooms in use" % [_ground_in_use, _ground_rooms]
	else:
		_summary.text = "Rank %s guild · %d of %d rooms in use" % [_rank, _ground_in_use, _ground_rooms]


# A room shows its name, its state by its fill, and an icon for what can be done there.
func _show_room(room: Room, slot: String, state: Hall.State, hall: Hall, now: int) -> void:
	var type := hall.room_type(slot)
	var look := Look.IN_USE
	var building := state == Hall.State.RESTORING or state == Hall.State.CONVERTING
	var kind := ""
	room.title.text = slot_name(hall, slot)
	match state:
		Hall.State.USABLE:
			if slot == STAIRS and not hall.has_first_floor(now):
				if hall.building == Hall.EXTENSION:
					room.bar.theme_type_variation = &"BuildBar"
					building = true
				elif hall.has_rank(Hall.EXTEND_RANK):
					kind = "build"
		Hall.State.CONVERTED:
			room.title.text = Hall.ROOM_TYPES[type]["name"]
			if type == "tavern":
				var held := hall.tavern_gold(slot, now)
				room.bar.theme_type_variation = &"GoldBar"
				room.bar.max_value = Hall.TAVERN_CAP
				room.bar.value = held
				if held > 0:
					kind = "collect"
			look = Look.INFIRMARY if type == "infirmary" else Look.CONVERTED
		Hall.State.RESTORED:
			kind = "job"
			look = Look.EMPTY
		Hall.State.DAMAGED:
			kind = "build"
			look = Look.DAMAGED
		Hall.State.RESTORING:
			room.bar.theme_type_variation = &"BuildBar"
			look = Look.RESTORING
		Hall.State.CONVERTING:
			room.bar.theme_type_variation = &"GoldBar"
			look = Look.CONVERTING
	if building:
		room.bar.max_value = hall.job_seconds()
		room.bar.value = room.bar.max_value - hall.seconds_left(now)
	room.bar.visible = building or (state == Hall.State.CONVERTED and type == "tavern")
	if kind != room.kind:
		room.kind = kind
		room.icon.texture = _icons.get(kind)
		room.icon.visible = not kind.is_empty()
		match kind:
			"build":
				room.action = extend_pressed.emit if slot == STAIRS else restore_pressed.emit.bind(slot)
			"job":
				room.action = job_pressed.emit.bind(slot)
			"collect":
				room.action = collect_pressed.emit.bind(slot)
			_:
				room.action = Callable()
	if look != room.look:
		room.look = look
		room.queue_redraw()


## `slot`'s name in `hall` until it is given a job.
static func slot_name(hall: Hall, slot: String) -> String:
	if hall.layout == Hall.OLD_LAYOUT:
		return OLD_SLOT_NAMES.get(slot, SLOT_NAMES[slot])
	return SLOT_NAMES[slot]


## Where the room `slot` is on screen, at its centre, for effects drawn over the hall.
func room_center(slot: String) -> Vector2:
	return _rooms[slot].get_global_rect().get_center()


# Adventurers at home: an injured one rests in the first finished Infirmary, or in Reception when
# there is none; one in training is in a finished Training room, one to a room in plan order; a
# ready one waits in Reception.
func _show_tokens(hall: Hall, dispatch: Dispatch, infirmary: String, now: int) -> void:
	var training_rooms := PackedStringArray()
	for slot: String in _rooms:
		if hall.room_type(slot) == "training_room" and hall.state(slot, now) == Hall.State.CONVERTED:
			training_rooms.append(slot)
	var trainees := 0
	var people: Dictionary[String, Array] = {}
	var roster := dispatch.adventurers.roster
	for adventurer: String in roster:
		if not dispatch.quest_of(adventurer).is_empty():
			continue
		var injured := dispatch.injury_left(adventurer, now) > 0
		var slot := infirmary if injured and not infirmary.is_empty() else "reception"
		if dispatch.training.has(adventurer) and not training_rooms.is_empty():
			slot = training_rooms[mini(trainees, training_rooms.size() - 1)]
			trainees += 1
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


# Timed rows first, each with its bar's full and current value and its seconds left: for most, the
# bar is how much of the total time has passed; for training, how much of the stint's XP is in. The
# Send row comes last.
func _show_progress(hall: Hall, dispatch: Dispatch, quests_on_board: int, now: int) -> void:
	var entries: Array[Dictionary] = []
	var waits: Array[Vector3i] = []
	for outing: Dictionary in dispatch.outings:
		var quest: Dictionary = Dispatch.QUESTS[outing["quest"]]
		entries.append({"tokens": outing["party"], "title": quest["name"], "bar": &"GoldBar"})
		var back_in := dispatch.seconds_left(outing, now)
		waits.append(Vector3i(quest["seconds"], quest["seconds"] - back_in, back_in))
	var build_left := hall.seconds_left(now)
	if build_left > 0:
		if hall.building == Hall.EXTENSION:
			entries.append({"swatch": Look.RESTORING, "title": "Building the first floor", "bar": &"BuildBar"})
		elif hall.building_into.is_empty():
			entries.append({"swatch": Look.RESTORING, "title": "Restoring the " + slot_name(hall, hall.building).to_lower(), "bar": &"BuildBar"})
		else:
			entries.append({"swatch": Look.CONVERTING, "title": "Converting the " + slot_name(hall, hall.building).to_lower(), "bar": &"GoldBar"})
		waits.append(Vector3i(hall.job_seconds(), hall.job_seconds() - build_left, build_left))
	# The line under a timed row's title that changes as it runs, "" for none, by timed row.
	var lines := PackedStringArray()
	lines.resize(waits.size())
	var at_hand := PackedStringArray()
	var roster := dispatch.adventurers.roster
	for adventurer: String in roster:
		var injury_left := dispatch.injury_left(adventurer, now)
		if injury_left > 0:
			var healing: String = roster[adventurer]["name"]
			entries.append({"tokens": [adventurer], "injured": true, "title": healing + " is healing", "bar": &"InjuryBar"})
			waits.append(Vector3i(dispatch.injury_seconds(adventurer), dispatch.injury_seconds(adventurer) - injury_left, injury_left))
			lines.append("")
		elif dispatch.training.has(adventurer):
			var gained := dispatch.training_xp(adventurer, now)
			if gained < Dispatch.TRAINING_MAX_XP:
				entries.append({"tokens": [adventurer], "title": roster[adventurer]["name"], "bar": &"OwnBar", "line": true})
				waits.append(Vector3i(Dispatch.TRAINING_MAX_XP, gained, dispatch.training_seconds_left(adventurer, now)))
				lines.append("Training · +%d / %d XP" % [gained, Dispatch.TRAINING_MAX_XP])
			else:
				entries.append({"tokens": [adventurer], "title": roster[adventurer]["name"], "sub": "Full — stop to bank", "sub_style": &"GoldText"})
		elif dispatch.can_go(adventurer, now):
			at_hand.append(adventurer)
	if not at_hand.is_empty() and quests_on_board > 0:
		# One ready shows their initial and name, several show how many.
		var one := at_hand.size() == 1
		entries.append({
			"tokens": [at_hand[0] if one else str(at_hand.size())],
			"title": "%s ready" % (roster[at_hand[0]]["name"] + " is" if one else str(at_hand.size())),
			"sub": "%d quest%s on the board" % [quests_on_board, "" if quests_on_board == 1 else "s"],
			"send": true,
		})
	if entries != _entries:
		_entries = entries
		_rebuild_rows(roster)
	for i: int in waits.size():
		_rows[i].bar.max_value = waits[i].x
		_rows[i].bar.value = waits[i].y
		_rows[i].time.text = Duration.label(waits[i].z)
		if _rows[i].line:
			_rows[i].line.text = lines[i]
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
			if entry.has("line"):
				row.line = _label("", &"Secondary")
				words.add_child(row.line)
			row.bar = _bar(entry["bar"])
			words.add_child(row.bar)
			row.time = _label("", &"Numbers")
			row.time.autowrap_mode = TextServer.AUTOWRAP_OFF
			line.add_child(row.time)
			_rows.append(row)
		else:
			words.add_child(_label(entry["sub"], entry.get("sub_style", &"Secondary")))
		var panel := PanelContainer.new()
		panel.theme_type_variation = &"ProgressRow"
		panel.add_child(line)
		if entry.has("send"):
			var go := Button.new()
			go.text = "Send →"
			go.theme_type_variation = &"GoldLink"
			go.pressed.connect(send_pressed.emit)
			line.add_child(go)
			_list_rows.add_child(Touch.whole_card(panel, go))
		else:
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
	_boxes.append(box)
	box.add_child(_label("Landing", &"RoomName"))
	landing.add_child(box)
	_lay(landing, LANDING, _upstairs)


func _add_room(slot: String, area: Rect2, layer: Control) -> void:
	var room := Room.new()
	room.draw.connect(func() -> void: _paint(room, room.look))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, ROOM_PADDING_PX)
	_boxes.append(box)
	room.add_child(box)
	room.title = _label("", &"RoomName")
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	room.tokens = HFlowContainer.new()
	room.tokens.visible = false
	room.bar = _bar(&"BuildBar")
	for part: Control in [room.title, spacer, room.tokens, room.bar]:
		box.add_child(part)
	room.icon = TextureRect.new()
	room.icon.visible = false
	room.icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	room.icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	room.icon.custom_minimum_size = Vector2(ICONS["build"].size(), ICONS["build"].size()) * ICON_SCALE
	room.add_child(room.icon)
	# Its minimum size grows out from the room's centre both ways, so the icon stays centred.
	room.icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	room.icon.grow_horizontal = Control.GROW_DIRECTION_BOTH
	room.icon.grow_vertical = Control.GROW_DIRECTION_BOTH
	# The whole room is one target: a tap anywhere on it does what its icon offers.
	var cover := Button.new()
	cover.flat = true
	cover.pressed.connect(func() -> void:
		if room.action.is_valid():
			room.action.call())
	room.add_child(cover)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lay(room, area, layer)
	_rooms[slot] = room


# `rows` of ICONS as an image, a pixel per character.
static func _pixel_image(rows: PackedStringArray) -> Texture2D:
	var image := Image.create_empty(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y: int in rows.size():
		for x: int in rows[y].length():
			image.set_pixel(x, y, ICON_COLORS.get(rows[y][x], Color.TRANSPARENT))
	return ImageTexture.create_from_image(image)


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
