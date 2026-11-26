class_name LabyrinthScreen
extends Control

## The labyrinth once it is open: the materials the guild holds, the elite expedition while one is
## open or has a party on it, and each floor, top to bottom, with how far it is explored and whether
## it can be sent to, has a party on it or is not open yet.

## The player asked to send a party on `quest`, a floor (a key of Labyrinth.FLOORS) or an elite, open
## with nobody on it.
signal send_pressed(quest: String)

## Each material's colour on its square.
const MATERIAL_COLORS: Dictionary[String, Color] = {"Glowmoss": Color("8fd18a"), "Riverglass": Color("7fb3d5"), "Bone silver": Color("d8cfc0")}
const MATERIAL_SQUARE_PX: Vector2 = Vector2(36, 36)
## The square a floor's depth number sits in.
const DEPTH_SIZE_PX: Vector2 = Vector2(72, 72)
## How tall a floor's explored bar and a party's time bar are: the design's 4 dp.
const BAR_PX: int = 11
## The space between a row's parts, and between its lines.
const ROW_GAP_PX: int = 22
const LINE_GAP_PX: int = 16

## Each floor's row, by its quest id, and its parts that change; and each elite's.
var _rows: Dictionary[String, FloorRow] = {}
var _elites: Dictionary[String, FloorRow] = {}
## Each material's count and the box that dims while its floor is not open, by its name.
var _counts: Dictionary[String, Label] = {}
var _materials: Dictionary[String, BoxContainer] = {}

@onready var _parties: Control = $Scroll/Box/Header/Parties
@onready var _parties_count: Label = $Scroll/Box/Header/Parties/Count
@onready var _material_row: HBoxContainer = $Scroll/Box/Materials/Row
@onready var _floors: VBoxContainer = $Scroll/Box/Floors
@onready var _deadly_section: Control = $Scroll/Box/DeadlySection
@onready var _deadly: VBoxContainer = $Scroll/Box/Deadly
@onready var _bonus: Label = $Scroll/Box/Bonus


## A floor's or an elite's row and its parts that change: a floor's name and depth line and how far
## it is explored, an elite's whole row and meta line; and below them Send with its challenges, the
## party out on it, or what opens the floor.
class FloorRow extends RefCounted:
	var row: Control
	var meta: Label
	var top: HBoxContainer
	var explored: Label
	var bar: ProgressBar
	var home: HBoxContainer
	var pills: HFlowContainer
	## How many of its challenges were unknown when the pills were built, so they change only on a
	## reveal; -1 before they are built.
	var unknown_shown: int = -1
	var send: Button
	var out: HBoxContainer
	var faces: HBoxContainer
	## The members whose faces show, so the faces change only when another party goes.
	var faces_shown: PackedStringArray = PackedStringArray()
	var party: Label
	var time_bar: ProgressBar
	var time: Label
	var locked: Label


func _ready() -> void:
	_floors.draw.connect(QuestBoard.draw_card.bind(_floors))
	_floors.sort_children.connect(_floors.queue_redraw)
	_deadly.draw.connect(QuestBoard.draw_card.bind(_deadly))
	_deadly.sort_children.connect(_deadly.queue_redraw)
	for quest: String in Dispatch.QUESTS:
		if Dispatch.is_elite(quest):
			_deadly.add_child(_elite_row(quest))
	var bonuses := PackedStringArray()
	var above := ""
	for floor_id: String in Labyrinth.FLOORS:
		var material: String = Labyrinth.FLOORS[floor_id]["material"]
		_material_row.add_child(_material(material))
		bonuses.append("%dg" % Labyrinth.FLOORS[floor_id]["clear_bonus"])
		_floors.add_child(_floor_row(floor_id, above))
		above = floor_id
	_bonus.text = "A floor explored to 100%% pays a one-time bonus: %s." % " · ".join(bonuses)


## Landscape shows how many parties are out beside the title, and each material on one line.
func set_landscape(landscape: bool) -> void:
	_parties.visible = landscape
	for material: String in _materials:
		_materials[material].vertical = not landscape


## Shows `dispatch`'s labyrinth at `now` for a guild whose goals have unlocked `unlocked`
## (Goals.unlocked) and that reached rank C at `rank_c_at` (Hall.ranked_at; negative for not yet):
## each material's count, dimmed while its floor is not open; the elite open (Dispatch.open_elites)
## or with a party out on it under DEADLY, which shows with neither; and each floor as open, with a
## party out on it, or not open yet.
func show_labyrinth(dispatch: Dispatch, unlocked: PackedStringArray, now: int, rank_c_at: int = -1) -> void:
	_parties_count.text = str(dispatch.outings.size())
	var open := dispatch.open_floors(unlocked)
	for floor_id: String in _rows:
		var material: String = Labyrinth.FLOORS[floor_id]["material"]
		_counts[material].text = str(dispatch.labyrinth.materials.get(material, 0))
		_materials[material].modulate = Color.WHITE if floor_id in open else Roster.DISABLED_ROW_TINT
		_show_floor(floor_id, floor_id in open, dispatch, now)
	var elites := dispatch.open_elites(rank_c_at, now)
	var deadly := false
	for elite: String in _elites:
		var parts := _elites[elite]
		var outing := _outing_on(elite, dispatch)
		parts.row.visible = elites.has(elite) or not outing.is_empty()
		deadly = deadly or parts.row.visible
		if not parts.row.visible:
			continue
		var info: Dictionary = Dispatch.QUESTS[elite]
		parts.meta.text = "%s · %s · %dg" % [info["rank"], Duration.label(info["seconds"]), info["gold"]]
		if outing.is_empty():
			parts.meta.text += " · closes in " + Duration.label(elites[elite] - now)
		_show_home_or_out(parts, elite, outing, dispatch, now)
	_deadly_section.visible = deadly
	_deadly.visible = deadly


# A material's square over its count over its name, each centred; in landscape on one line.
func _material(material: String) -> BoxContainer:
	var square := ColorRect.new()
	square.color = MATERIAL_COLORS[material]
	square.custom_minimum_size = MATERIAL_SQUARE_PX
	square.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_counts[material] = _label("0", &"Numbers")
	var box := BoxContainer.new()
	box.vertical = true
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	for part: Control in [square, _counts[material], _label(material, &"Caption")]:
		part.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(part)
	_materials[material] = box
	return box


# The row of `floor_id`, under the floor `above` ("" for the first): its depth, name and meta line with
# how far it is explored and a bar, over its challenges and Send, the party out on it, or what opens
# it. A tap anywhere on it presses Send while Send shows.
func _floor_row(floor_id: String, above: String) -> MarginContainer:
	var info: Dictionary = Dispatch.QUESTS[floor_id]
	var parts := FloorRow.new()
	var depth := QuestBoard.chip(str(info["floor"]), &"Pill")
	depth.custom_minimum_size = DEPTH_SIZE_PX
	depth.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	depth.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	depth.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(QuestBoard.one_line(info["name"], &"RowTitle"))
	words.add_child(QuestBoard.one_line("%s · %s · %dg · %s" % [info["rank"], Duration.label(info["seconds"]), info["gold"], Labyrinth.FLOORS[floor_id]["material"]], &"MetaSmall"))
	parts.explored = _label("", &"Gain")
	parts.top = HBoxContainer.new()
	parts.top.add_theme_constant_override("separation", ROW_GAP_PX)
	parts.top.add_child(depth)
	parts.top.add_child(words)
	parts.top.add_child(parts.explored)
	parts.bar = _bar(&"HealthBar")
	parts.bar.max_value = 100
	_home_and_out(parts, floor_id)
	parts.locked = _label("" if above.is_empty() else "Opens when %s is %d%% explored" % [Dispatch.QUESTS[above]["name"], Labyrinth.NEXT_FLOOR_AT], &"Caption")
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", LINE_GAP_PX)
	for part: Control in [parts.top, parts.bar, parts.home, parts.out, parts.locked]:
		lines.add_child(part)
	var card := PanelContainer.new()
	card.theme_type_variation = &"CardRow"
	card.add_child(lines)
	_rows[floor_id] = parts
	return Touch.whole_card(card, parts.send)


# The row of elite `quest`: its name and Deadly tag over its meta line, then its challenges and Send
# or the party out on it. A tap anywhere on it presses Send while Send shows.
func _elite_row(quest: String) -> MarginContainer:
	var parts := FloorRow.new()
	var tag := QuestBoard.chip("Deadly", &"PillUncovered")
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", LINE_GAP_PX)
	heading.add_child(QuestBoard.one_line(Dispatch.QUESTS[quest]["name"], &"RowTitle"))
	heading.add_child(tag)
	parts.meta = QuestBoard.one_line("", &"MetaSmall")
	_home_and_out(parts, quest)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", LINE_GAP_PX)
	for part: Control in [heading, parts.meta, parts.home, parts.out]:
		lines.add_child(part)
	var card := PanelContainer.new()
	card.theme_type_variation = &"CardRow"
	card.add_child(lines)
	_elites[quest] = parts
	parts.row = Touch.whole_card(card, parts.send)
	return parts.row


# Makes `parts`' challenges with Send, which asks to send a party on `quest`, and the line showing
# the party out on it.
func _home_and_out(parts: FloorRow, quest: String) -> void:
	parts.pills = HFlowContainer.new()
	parts.pills.theme_type_variation = &"Chips"
	parts.pills.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parts.send = Button.new()
	parts.send.text = "Send ›"
	parts.send.theme_type_variation = &"GoldLink"
	parts.send.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parts.send.pressed.connect(send_pressed.emit.bind(quest))
	parts.home = HBoxContainer.new()
	parts.home.add_theme_constant_override("separation", ROW_GAP_PX)
	parts.home.add_child(parts.pills)
	parts.home.add_child(parts.send)
	parts.faces = HBoxContainer.new()
	parts.faces.theme_type_variation = &"TokenStack"
	parts.party = QuestBoard.one_line("", &"Caption")
	parts.party.size_flags_stretch_ratio = 2.0
	parts.time_bar = _bar(&"GoldBar")
	parts.time = _label("", &"Numbers")
	parts.time.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parts.out = HBoxContainer.new()
	parts.out.add_theme_constant_override("separation", LINE_GAP_PX)
	for part: Control in [parts.faces, parts.party, parts.time_bar, parts.time]:
		parts.out.add_child(part)


# Shows `floor_id`'s row at `now`: dimmed with what opens it while not `open`; else how far it is
# explored, "Cleared" at 100, over the party out on it with its time left, or its challenges and Send.
func _show_floor(floor_id: String, open: bool, dispatch: Dispatch, now: int) -> void:
	var parts := _rows[floor_id]
	var explored := dispatch.labyrinth.explored_percent(floor_id)
	parts.top.modulate = Color.WHITE if open else Roster.DISABLED_ROW_TINT
	parts.locked.visible = not open
	parts.explored.visible = open
	parts.bar.visible = open
	if not open:
		parts.home.visible = false
		parts.out.visible = false
		return
	parts.explored.text = "Cleared" if explored >= 100 else "%d%%" % explored
	parts.bar.value = explored
	_show_home_or_out(parts, floor_id, _outing_on(floor_id, dispatch), dispatch, now)


# The party out on `quest` in `dispatch`, or {} for none.
static func _outing_on(quest: String, dispatch: Dispatch) -> Dictionary:
	for outing: Dictionary in dispatch.outings:
		if outing["quest"] == quest:
			return outing
	return {}


# Shows on `parts` `outing`, the party out on `quest`, with its time left at `now`; or, with nobody
# out ({}), the quest's challenges and Send.
func _show_home_or_out(parts: FloorRow, quest: String, outing: Dictionary, dispatch: Dispatch, now: int) -> void:
	parts.home.visible = outing.is_empty()
	parts.out.visible = not outing.is_empty()
	if outing.is_empty():
		var unknown := dispatch.unknown_challenges(quest)
		if unknown.size() != parts.unknown_shown:
			parts.unknown_shown = unknown.size()
			_clear(parts.pills)
			for challenge: String in Dispatch.QUESTS[quest]["challenges"]:
				parts.pills.add_child(QuestBoard.chip("?", &"PillUnknown") if challenge in unknown else QuestBoard.chip(challenge, &"Pill"))
		return
	var party: PackedStringArray = outing["party"]
	if party != parts.faces_shown:
		parts.faces_shown = party.duplicate()
		_clear(parts.faces)
		for adventurer: String in party:
			parts.faces.add_child(QuestBoard.token(adventurer, dispatch.adventurers.roster))
	parts.party.text = dispatch.adventurers.parties.party(outing.get("party_id", "")).get("name", "")
	var from: int = outing["since"]
	var to := dispatch.back_at(outing)
	var left := dispatch.seconds_left(outing, now)
	parts.time_bar.max_value = to - from
	parts.time_bar.value = to - from - left
	parts.time.text = Duration.label(left)


static func _clear(box: Container) -> void:
	for old: Node in box.get_children():
		box.remove_child(old)
		old.queue_free()


static func _bar(variation: StringName) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.theme_type_variation = variation
	bar.show_percentage = false
	bar.step = 1.0
	bar.custom_minimum_size = Vector2(0, BAR_PX)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return bar


static func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	return label
