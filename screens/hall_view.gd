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
## The player tapped the finished room `slot`, to upgrade it to its next tier.
signal upgrade_pressed(slot: String)
## The player tapped the Reception, to see the guild's rank.
signal reception_pressed

## How a room is drawn on the plan. UNBUILT is a room the hall doesn't have yet: not drawn at all.
enum Look { IN_USE, EMPTY, DAMAGED, RESTORING, CONVERTING, UNBUILT }

# The Ground floor seen from above, as fractions of the floor: y = 0 is the back wall, y = 1 the
# front, at the bottom of the screen.
const GROUND_FLOOR: Dictionary[String, Rect2] = {
	"back_left": Rect2(0.0, 0.0, 0.5, 0.3),
	"back_right": Rect2(0.5, 0.0, 0.5, 0.3),
	"side_left": Rect2(0.0, 0.3, 0.3, 0.4),
	"reception": Rect2(0.3, 0.3, 0.4, 0.4),
	"side_right": Rect2(0.7, 0.3, 0.3, 0.4),
	"entrance": Rect2(0.0, 0.7, 1.0, 0.3),
	"front_right": Rect2(0.6, 0.7, 0.4, 0.3),
}
## The room that splits the front strip once the hall has it: the entrance hall keeps the left part,
## SPLIT_ENTRANCE, and its doorways are SPLIT_DOORS.
const FRONT_ROOM: String = "front_right"
const SPLIT_ENTRANCE: Rect2 = Rect2(0.0, 0.7, 0.6, 0.3)
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
	"front_right": "Front room",
}
## The names a hall saved before guild ranks keeps for its rooms where SLOT_NAMES differs.
const OLD_SLOT_NAMES: Dictionary[String, String] = {
	"back_left": "North-west room",
	"side_left": "West room",
}

## Doorways, each the middle of its gap as fractions of the floor like the rooms, and the room it
## opens into: a doorway into a room the hall doesn't have is wall. On the Ground floor the
## Reception's front door, the entrance hall's, and a door from each room into the Reception; on
## the First floor a door from each room towards the landing.
const GROUND_DOORS: Dictionary[Vector2, String] = {
	Vector2(0.6, 0.7): "reception",
	Vector2(0.5, 1.0): "entrance",
	Vector2(0.3, 0.5): "side_left",
	Vector2(0.7, 0.5): "side_right",
	Vector2(0.4, 0.3): "back_left",
	Vector2(0.6, 0.3): "back_right",
}
## The Ground floor's doorways once FRONT_ROOM splits the front: the front door in the middle of
## the entrance hall, the Reception's moved off the new wall, and the front room's into the
## entrance hall.
const SPLIT_DOORS: Dictionary[Vector2, String] = {
	Vector2(0.55, 0.7): "reception",
	Vector2(0.3, 1.0): "entrance",
	Vector2(0.6, 0.85): "front_right",
	Vector2(0.3, 0.5): "side_left",
	Vector2(0.7, 0.5): "side_right",
	Vector2(0.4, 0.3): "back_left",
	Vector2(0.6, 0.3): "back_right",
}
const FIRST_DOORS: Dictionary[Vector2, String] = {
	Vector2(0.25, 0.8): "upper_sw",
	Vector2(0.75, 0.8): "upper_se",
	Vector2(0.25, 0.4): "upper_nw",
	Vector2(0.75, 0.4): "upper_ne",
}
## The floor's size in metres, the same on both floors. Rooms and furniture are laid out in metres;
## the plan draws what is built of the floor shown, centred, at the scale that makes it fill
## PLAN_FILL of the plan, so the plan keeps its size whatever is built.
const FLOOR_M: Vector2 = Vector2(20.0, 16.0)
const PLAN_FILL: float = 0.68
const DOOR_M: float = 1.0
const WALL_PX: float = 8.0
## A damaged room's walls are thinner and dashed, as are the legend's.
const THIN_WALL_PX: float = 6.0
const DASH_PX: float = 8.0
## A damaged room's hatching: thin lines this far apart, rising to the right.
const HATCH_STEP_PX: float = 30.0
const HATCH_PX: float = 3.0
## Where a room's name sits inside its walls, from the top-left corner; and its progress bar, from
## the bottom and sides.
const NAME_INSET_PX: Vector2 = Vector2(14.0, 18.0)
const BAR_INSET_PX: Vector2 = Vector2(22.0, 25.0)
const BAR_PX: float = 12.0
const WALL: Color = Color("#f1ebf4")
## The walls of work under way.
const WORK: Color = Color("#f2c14e")
const HATCH: Color = Color("#cfc6d6", 0.13)
## Furniture is faint, in the background: outlines in INK over FILL.
const FURNITURE_INK: Color = Color("#3a3446")
const FURNITURE_FILL: Color = Color("#221d29")
const FURNITURE_PX: float = 3.0
const FURNITURE_DASH_PX: float = 5.0
## Where furniture is measured from, as fractions of its room.
const TOP_LEFT: Vector2 = Vector2(0.0, 0.0)
const TOP_RIGHT: Vector2 = Vector2(1.0, 0.0)
const CENTRE: Vector2 = Vector2(0.5, 0.5)
const FRONT_MIDDLE: Vector2 = Vector2(0.5, 1.0)
## The Reception's furniture but its front door's swing, which moves with that doorway, as FURNITURE.
const RECEPTION: Array = [
	# A notice board on the back wall, the counter with a stool behind it, a bench by the front wall,
	# and a round table with four stools.
	["slab", TOP_LEFT, Rect2(5.2, 0.09, 1.52, 0.15)],
	["box", TOP_LEFT, Rect2(5.99, 1.78, 0.66, 2.64)],
	["line", TOP_LEFT, Vector2(5.99, 2.18), Vector2(6.65, 2.18)],
	["line", TOP_LEFT, Vector2(5.99, 4.02), Vector2(6.65, 4.02)],
	["seat", TOP_LEFT, Vector2(7.2, 3.1), 0.2],
	["box", TOP_LEFT, Rect2(0.77, 6.06, 3.56, 0.25)],
	["disc", TOP_LEFT, Vector2(2.73, 3.47), 0.51],
	["seat", TOP_LEFT, Vector2(2.155, 2.895), 0.18],
	["seat", TOP_LEFT, Vector2(3.305, 2.895), 0.18],
	["seat", TOP_LEFT, Vector2(2.155, 4.045), 0.18],
	["seat", TOP_LEFT, Vector2(3.305, 4.045), 0.18],
	# Its doors' swings, at its doorways in GROUND_DOORS: into the Backroom and into the Side room.
	["line", TOP_LEFT, Vector2(1.5, 0.0), Vector2(1.5, -1.0)],
	["arc", TOP_LEFT, Vector2(1.5, 0.0), 1.0, 0.0, -PI / 2.0],
	["line", TOP_LEFT, Vector2(0.0, 3.7), Vector2(-1.0, 3.7)],
	["arc", TOP_LEFT, Vector2(0.0, 3.7), 1.0, -PI / 2.0, -PI],
]
## What stands in a room in use, by its type, or by its slot for the Reception and the entrance
## hall; "split_reception" is the Reception once FRONT_ROOM splits the front. Each piece is its
## shape, the point of the room it is measured from, then in metres from there: "box" a filled
## outline, "frame" an outline, "slab" a solid block, each a Rect2; "line" and "dash" from one point
## to another; "seat" an outlined and "disc" a filled circle, at a centre with a radius; "arc" a
## centre, a radius and the angles it runs between.
const FURNITURE: Dictionary[String, Array] = {
	# The front door opening in, at its doorway in GROUND_DOORS, or in SPLIT_DOORS.
	"reception": RECEPTION + [
		["line", TOP_LEFT, Vector2(6.5, 6.4), Vector2(6.5, 5.4)],
		["arc", TOP_LEFT, Vector2(6.5, 6.4), 1.0, PI, PI * 1.5],
	],
	"split_reception": RECEPTION + [
		["line", TOP_LEFT, Vector2(5.5, 6.4), Vector2(5.5, 5.4)],
		["arc", TOP_LEFT, Vector2(5.5, 6.4), 1.0, PI, PI * 1.5],
	],
	"entrance": [
		# A doormat at the front door, and the staircase.
		["box", FRONT_MIDDLE, Rect2(-0.7, -0.75, 1.4, 0.6)],
		["box", TOP_RIGHT, Rect2(-4.0, 0.9, 3.2, 1.2)],
		["line", TOP_RIGHT, Vector2(-3.6, 0.9), Vector2(-3.6, 2.1)],
		["line", TOP_RIGHT, Vector2(-3.2, 0.9), Vector2(-3.2, 2.1)],
		["line", TOP_RIGHT, Vector2(-2.8, 0.9), Vector2(-2.8, 2.1)],
		["line", TOP_RIGHT, Vector2(-2.4, 0.9), Vector2(-2.4, 2.1)],
		["line", TOP_RIGHT, Vector2(-2.0, 0.9), Vector2(-2.0, 2.1)],
		["line", TOP_RIGHT, Vector2(-1.6, 0.9), Vector2(-1.6, 2.1)],
		["line", TOP_RIGHT, Vector2(-1.2, 0.9), Vector2(-1.2, 2.1)],
	],
	"bunk_room": [
		# Two bunks, each with a pillow and a folded blanket, and a chest.
		["box", TOP_RIGHT, Rect2(-3.43, 0.55, 2.0, 0.8)],
		["frame", TOP_RIGHT, Rect2(-3.28, 0.7, 0.36, 0.51)],
		["dash", TOP_RIGHT, Vector2(-2.72, 0.95), Vector2(-1.55, 0.95)],
		["box", TOP_RIGHT, Rect2(-3.43, 1.9, 2.0, 0.8)],
		["frame", TOP_RIGHT, Rect2(-3.28, 2.05, 0.36, 0.51)],
		["dash", TOP_RIGHT, Vector2(-2.72, 2.3), Vector2(-1.55, 2.3)],
		["box", TOP_RIGHT, Rect2(-0.79, 0.52, 0.46, 0.61)],
	],
	"common_room": [
		# A hearth on the left wall, and a table with six chairs.
		["box", TOP_LEFT, Rect2(0.15, 1.75, 0.3, 1.22)],
		["arc", TOP_LEFT, Vector2(0.45, 2.36), 0.41, -PI / 2.0, PI / 2.0],
		["box", TOP_LEFT, Rect2(1.795, 2.21, 1.63, 0.92)],
		["frame", TOP_LEFT, Rect2(2.1, 1.86, 0.31, 0.25)],
		["frame", TOP_LEFT, Rect2(2.81, 1.86, 0.31, 0.25)],
		["frame", TOP_LEFT, Rect2(2.1, 3.23, 0.31, 0.25)],
		["frame", TOP_LEFT, Rect2(2.81, 3.23, 0.31, 0.25)],
		["frame", TOP_LEFT, Rect2(1.39, 2.52, 0.25, 0.31)],
		["frame", TOP_LEFT, Rect2(3.58, 2.52, 0.25, 0.31)],
	],
	"infirmary": [
		# Three cots, each with a pillow.
		["box", TOP_RIGHT, Rect2(-1.2, 0.55, 0.8, 1.9)],
		["frame", TOP_RIGHT, Rect2(-1.05, 0.7, 0.5, 0.3)],
		["box", TOP_RIGHT, Rect2(-2.4, 0.55, 0.8, 1.9)],
		["frame", TOP_RIGHT, Rect2(-2.25, 0.7, 0.5, 0.3)],
		["box", TOP_RIGHT, Rect2(-3.6, 0.55, 0.8, 1.9)],
		["frame", TOP_RIGHT, Rect2(-3.45, 0.7, 0.5, 0.3)],
	],
	"tavern": [
		# A bar along the right wall and three stools in front of it.
		["box", TOP_RIGHT, Rect2(-1.1, 0.55, 0.66, 3.0)],
		["seat", TOP_RIGHT, Vector2(-1.6, 1.05), 0.2],
		["seat", TOP_RIGHT, Vector2(-1.6, 2.05), 0.2],
		["seat", TOP_RIGHT, Vector2(-1.6, 3.05), 0.2],
	],
	"training_room": [
		# A dummy with its arms out, and a weapon rack on the right wall.
		["line", CENTRE, Vector2(-0.6, 0.0), Vector2(0.6, 0.0)],
		["disc", CENTRE, Vector2.ZERO, 0.3],
		["box", TOP_RIGHT, Rect2(-0.55, 1.4, 0.3, 2.4)],
		["line", TOP_RIGHT, Vector2(-0.55, 2.0), Vector2(-0.25, 2.0)],
		["line", TOP_RIGHT, Vector2(-0.55, 2.6), Vector2(-0.25, 2.6)],
		["line", TOP_RIGHT, Vector2(-0.55, 3.2), Vector2(-0.25, 3.2)],
	],
	"map_room": [
		# A map table with a map on it and a route drawn across.
		["box", CENTRE, Rect2(-1.2, -0.75, 2.4, 1.5)],
		["frame", CENTRE, Rect2(-1.0, -0.55, 2.0, 1.1)],
		["dash", CENTRE, Vector2(-0.8, 0.35), Vector2(0.8, -0.35)],
	],
	"quest_hall": [
		# A quest board on the back wall, and a desk with a chair.
		["slab", TOP_RIGHT, Rect2(-3.2, 0.09, 2.4, 0.15)],
		["box", CENTRE, Rect2(-0.8, -0.3, 1.6, 0.7)],
		["frame", CENTRE, Rect2(-0.15, 0.55, 0.3, 0.25)],
	],
	"storeroom": [
		# Shelves along the right wall, and two crates.
		["box", TOP_RIGHT, Rect2(-1.05, 0.55, 0.5, 3.0)],
		["line", TOP_RIGHT, Vector2(-1.05, 1.55), Vector2(-0.55, 1.55)],
		["line", TOP_RIGHT, Vector2(-1.05, 2.55), Vector2(-0.55, 2.55)],
		["frame", TOP_RIGHT, Rect2(-2.6, 0.6, 0.9, 0.9)],
		["frame", TOP_RIGHT, Rect2(-2.6, 1.8, 0.9, 0.9)],
	],
}
## What a room's icon offers: a damaged room or the stairs to build, an empty room to give a job, a
## Tavern's gold to collect, the Reception's crest when the guild can rank up; a room with a next
## tier its rank allows shows "build" too, to upgrade it. Each a pixel
## image, a row of characters per line, coloured by ICON_COLORS; "." is see-through.
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
	"crest": [
		"................",
		"..oooooooooooo..",
		"..ohhhhhhhhhho..",
		"..ohhhhhhhhhho..",
		"..ohhhhgghhhho..",
		"..ohhhgggghhho..",
		"..ohhgghhgghho..",
		"..ohgghhhhggho..",
		"..ohhhhhhhhhho..",
		"..ohhhhgghhhho..",
		"...ohhgggghho...",
		"....ogghhggo....",
		".....ohhhho.....",
		"......ohho......",
		".......oo.......",
		"................",
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
## Where the whole floor is drawn on the plan; each floor's layer covers it.
var _building: Control
## Each floor's rooms, shown one floor at a time, and how many of them are in use.
var _ground: Control
var _upstairs: Control
var _ground_in_use: int = 0
var _upstairs_in_use: int = 0
var _ground_rooms: int = 0
## The part of the Ground floor that is built, as fractions of the floor; the plan centres it.
var _ground_built: Rect2 = Rect2(0.0, 0.0, 1.0, 1.0)
## Whether the hall has FRONT_ROOM, which splits the front strip.
var _split: bool = false
## The guild's rank, shown in place of the floor's name when the hall has only one floor.
var _rank: String = ""
## ICONS drawn once, by kind.
var _icons: Dictionary[String, Texture2D] = {}

## Odile's goals: under the header in portrait, at the top of the In progress column in landscape.
@onready var goals_card: GoalsCard = $Scroll/Box/Top/Goals
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
	## Where the room is on its floor, as fractions, and the doorways in its floor's walls.
	var area: Rect2
	var doors: Dictionary[Vector2, String]
	## The key of FURNITURE drawn in the room; "" for none.
	var furniture: String = ""
	var title: Label
	var bar: ProgressBar
	## The icon for `kind`, centred on the room; hidden when `kind` has none (ICONS, or "upgrade").
	var icon: TextureRect
	## What can be done here: a key of ICONS, "reception" (opens the Reception on a tap, with no
	## icon; with "crest" it opens it too), or "" for nothing.
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
	_icons["upgrade"] = _icons["build"]
	_building = Control.new()
	_building.mouse_filter = Control.MOUSE_FILTER_PASS
	_plan.add_child(_building)
	_plan.resized.connect(_place_building)
	_ground = _add_floor()
	_upstairs = _add_floor()
	_upstairs.visible = false
	for slot: String in GROUND_FLOOR:
		_add_room(slot, GROUND_FLOOR[slot], _ground, GROUND_DOORS)
	for slot: String in FIRST_FLOOR:
		_add_room(slot, FIRST_FLOOR[slot], _upstairs, FIRST_DOORS)
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


## Landscape puts the floor bar beside the header and the goals with In progress under them beside
## the plan, shows how many parties are out in the header, and leaves out the legend; portrait
## stacks them all, the goals under the header. In landscape the floor summary keeps to one line:
## the title is smaller and the header takes the width the summary needs from the floor bar.
func set_landscape(landscape: bool) -> void:
	var top := $Scroll/Box/Top as BoxContainer
	top.vertical = not landscape
	($Scroll/Box/Columns as BoxContainer).vertical = not landscape
	var goals_box: Control = $Scroll/Box/Columns/Right if landscape else top
	goals_card.reparent(goals_box, false)
	goals_box.move_child(goals_card, 0 if landscape else 1)
	_parties.visible = landscape
	_legend.visible = not landscape
	($Scroll/Box/Top/Header/Title as Label).theme_type_variation = &"Heading" if landscape else &"Title"
	_summary.autowrap_mode = TextServer.AUTOWRAP_OFF if landscape else TextServer.AUTOWRAP_WORD_SMART


## Shows the hall, who is home, and what is under way at `now`; `quests_on_board` is how many
## quests the board offers.
func show_state(hall: Hall, dispatch: Dispatch, quests_on_board: int, now: int) -> void:
	_ground_in_use = 0
	_upstairs_in_use = 0
	_ground_rooms = 0
	var split := hall.state(FRONT_ROOM, now) != Hall.State.UNBUILT
	if split != _split:
		_split = split
		_rooms["entrance"].area = SPLIT_ENTRANCE if split else GROUND_FLOOR["entrance"]
		_anchor(_rooms["entrance"], _rooms["entrance"].area)
		for slot: String in GROUND_FLOOR:
			_rooms[slot].doors = SPLIT_DOORS if split else GROUND_DOORS
			_rooms[slot].queue_redraw()
	# Only a hall with stairs has floors to choose from: one from before guild ranks, which always
	# had them, or one whose First floor is built.
	_floors.visible = hall.from_before_ranks() or hall.has_first_floor(now)
	var rank_up := hall.rank_up_refusal(dispatch.reputation, dispatch.gold, dispatch.adventurers.parties.parties.size(), dispatch.story_done, now).is_empty()
	var built := Rect2()
	for slot: String in _rooms:
		var state := hall.state(slot, now)
		if slot not in FIRST_FLOOR and state != Hall.State.UNBUILT:
			built = _rooms[slot].area if not built.has_area() else built.merge(_rooms[slot].area)
		_show_room(_rooms[slot], slot, state, hall, now, rank_up)
		# The rank summary counts rooms, not the entrance hall; the Ground floor's, kept as it was
		# before ranks, counts it too.
		if state == Hall.State.UNBUILT or (slot == STAIRS and not _floors.visible):
			continue
		if slot not in FIRST_FLOOR:
			_ground_rooms += 1
		if state == Hall.State.USABLE or state == Hall.State.CONVERTED:
			if slot in FIRST_FLOOR:
				_upstairs_in_use += 1
			else:
				_ground_in_use += 1
	if built != _ground_built:
		_ground_built = built
		_place_building()
	_first_button.disabled = not hall.has_first_floor(now)
	_rank = hall.rank
	_show_summary()
	_parties_count.text = str(dispatch.outings.size())
	_show_progress(hall, dispatch, quests_on_board, now)


func _on_first_toggled(upstairs: bool) -> void:
	_ground.visible = not upstairs
	_upstairs.visible = upstairs
	_show_summary()
	_place_building()


func _show_summary() -> void:
	if _upstairs.visible:
		_summary.text = "First floor · %d of %d rooms in use" % [_upstairs_in_use, FIRST_FLOOR.size()]
	elif _floors.visible:
		_summary.text = "Ground floor · %d of %d rooms in use" % [_ground_in_use, _ground_rooms]
	else:
		_summary.text = "Rank %s guild · %d of %d rooms in use" % [_rank, _ground_in_use, _ground_rooms]


# A room shows its name, its state by its walls and fill, its furniture once it is in use, and an
# icon for what can be done there; the Reception's crest when `rank_up` says the guild can rank up.
func _show_room(room: Room, slot: String, state: Hall.State, hall: Hall, now: int, rank_up: bool) -> void:
	var type := hall.room_type(slot)
	var look := Look.IN_USE
	var building := state == Hall.State.RESTORING or state == Hall.State.CONVERTING
	var kind := ""
	var furniture := slot
	if slot == "reception" and _split:
		furniture = "split_reception"
	elif slot == STAIRS and not _floors.visible:
		# A hall without stairs has an empty entrance hall.
		furniture = ""
	room.title.text = slot_name(hall, slot)
	match state:
		Hall.State.USABLE:
			# The Reception opens on a tap, with no icon unless the guild can rank up.
			if slot == "reception":
				kind = "crest" if rank_up else "reception"
			elif slot == STAIRS and not hall.has_first_floor(now):
				if hall.building == Hall.EXTENSION:
					room.bar.theme_type_variation = &"PlanBar"
					building = true
				elif hall.has_rank(Hall.EXTEND_RANK):
					kind = "build"
		Hall.State.CONVERTED:
			room.title.text = Hall.ROOM_TYPES[type]["name"]
			furniture = type
			if slot == hall.building and hall.seconds_left(now) > 0:
				# Being upgraded: it stays in use, with the builder's bar.
				room.bar.theme_type_variation = &"PlanBar"
				building = true
			elif type == "tavern":
				# A Tavern with gold offers collecting before upgrading.
				var held := hall.tavern_gold(slot, now)
				room.bar.theme_type_variation = &"GoldBar"
				room.bar.max_value = hall.tavern_cap(slot, now)
				room.bar.value = held
				if held > 0:
					kind = "collect"
			# Short gold or a busy builder still shows it, and the card says why.
			if kind.is_empty() and not building and hall.rank_allows_upgrade(slot, now):
				kind = "upgrade"
		Hall.State.RESTORED:
			kind = "job"
			look = Look.EMPTY
		Hall.State.DAMAGED:
			kind = "build"
			look = Look.DAMAGED
		Hall.State.RESTORING:
			room.bar.theme_type_variation = &"PlanBar"
			look = Look.RESTORING
		Hall.State.CONVERTING:
			room.bar.theme_type_variation = &"PlanBar"
			look = Look.CONVERTING
		Hall.State.UNBUILT:
			look = Look.UNBUILT
	if look != Look.IN_USE or furniture not in FURNITURE:
		furniture = ""
	room.visible = look != Look.UNBUILT
	if building:
		room.bar.max_value = hall.job_seconds()
		room.bar.value = room.bar.max_value - hall.seconds_left(now)
	room.bar.visible = building or (state == Hall.State.CONVERTED and type == "tavern")
	if kind != room.kind:
		room.kind = kind
		room.icon.texture = _icons.get(kind)
		room.icon.visible = kind in _icons
		match kind:
			"reception", "crest":
				room.action = reception_pressed.emit
			"build":
				room.action = extend_pressed.emit if slot == STAIRS else restore_pressed.emit.bind(slot)
			"upgrade":
				room.action = upgrade_pressed.emit.bind(slot)
			"job":
				room.action = job_pressed.emit.bind(slot)
			"collect":
				room.action = collect_pressed.emit.bind(slot)
			_:
				room.action = Callable()
	if furniture != room.furniture:
		room.furniture = furniture
		room.queue_redraw()
	if look != room.look:
		room.look = look
		# Its neighbours too: whether their doorways into it are open depends on its look.
		for other: Room in _rooms.values():
			other.queue_redraw()


## `slot`'s name in `hall` until it is given a job.
static func slot_name(hall: Hall, slot: String) -> String:
	if hall.from_before_ranks():
		return OLD_SLOT_NAMES.get(slot, SLOT_NAMES[slot])
	return SLOT_NAMES[slot]


## Where the room `slot` is on screen, at its centre, for effects drawn over the hall.
func room_center(slot: String) -> Vector2:
	return _rooms[slot].get_global_rect().get_center()


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
			entries.append({"swatch": Look.RESTORING, "title": "Building the first floor", "bar": &"GoldBar"})
		elif hall.building_into.is_empty():
			entries.append({"swatch": Look.RESTORING, "title": "Restoring the " + slot_name(hall, hall.building).to_lower(), "bar": &"GoldBar"})
		elif hall.building_tier > 0:
			entries.append({"swatch": Look.CONVERTING, "title": "Upgrading the " + Hall.ROOM_TYPES[hall.building_into]["name"].to_lower(), "bar": &"GoldBar"})
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
			var stint_xp := hall.stint_xp(now)
			var gained := dispatch.training_xp(adventurer, now, stint_xp)
			if gained < stint_xp:
				entries.append({"tokens": [adventurer], "title": roster[adventurer]["name"], "bar": &"OwnBar", "line": true})
				waits.append(Vector3i(stint_xp, gained, dispatch.training_seconds_left(adventurer, now, stint_xp)))
				lines.append("Training · +%d / %d XP" % [gained, stint_xp])
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
			line.add_child(_swatch(entry["swatch"], Vector2(88, 88)))
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


# A floor's layer over the whole floor, for its rooms.
func _add_floor() -> Control:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_PASS
	_building.add_child(layer)
	return layer


# Puts `item` on `layer` over `area`, a fraction of the floor.
func _lay(item: Control, area: Rect2, layer: Control) -> void:
	_anchor(item, area)
	layer.add_child(item)


# Spans `item` over `area`, a fraction of the floor its layer covers.
static func _anchor(item: Control, area: Rect2) -> void:
	item.anchor_left = area.position.x
	item.anchor_top = area.position.y
	item.anchor_right = area.end.x
	item.anchor_bottom = area.end.y


# The First floor's landing: drawn as a room in use, with nothing to do there.
func _add_landing() -> void:
	var landing := Control.new()
	landing.draw.connect(_paint.bind(landing, Look.IN_USE, LANDING, FIRST_DOORS, ""))
	_room_name(landing).text = "Landing"
	_lay(landing, LANDING, _upstairs)


func _add_room(slot: String, area: Rect2, layer: Control, doors: Dictionary[Vector2, String]) -> void:
	var room := Room.new()
	room.area = area
	room.doors = doors
	room.draw.connect(func() -> void: _paint(room, room.look, room.area, room.doors, room.furniture))
	# What is in the room stays inside it; its walls do not, so neighbours share them.
	var inside := Control.new()
	inside.clip_contents = true
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inside.set_anchors_preset(Control.PRESET_FULL_RECT)
	room.add_child(inside)
	room.title = _room_name(inside)
	# The bar runs along the bottom of the room, inside its walls.
	room.bar = _bar(&"PlanBar")
	inside.add_child(room.bar)
	room.bar.anchor_top = 1.0
	room.bar.anchor_right = 1.0
	room.bar.anchor_bottom = 1.0
	room.bar.offset_left = WALL_PX / 2.0 + BAR_INSET_PX.x
	room.bar.offset_right = -room.bar.offset_left
	room.bar.offset_bottom = -(WALL_PX / 2.0 + BAR_INSET_PX.y)
	room.bar.offset_top = room.bar.offset_bottom - BAR_PX
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


# A room's name on `parent`, tucked into its top-left corner inside the walls.
func _room_name(parent: Control) -> Label:
	var title := _label("", &"RoomName")
	title.uppercase = true
	parent.add_child(title)
	title.anchor_right = 1.0
	title.offset_left = WALL_PX / 2.0 + NAME_INSET_PX.x
	title.offset_top = WALL_PX / 2.0 + NAME_INSET_PX.y
	title.offset_right = -title.offset_left
	return title


# `rows` of ICONS as an image, a pixel per character.
static func _pixel_image(rows: PackedStringArray) -> Texture2D:
	var image := Image.create_empty(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y: int in rows.size():
		for x: int in rows[y].length():
			image.set_pixel(x, y, ICON_COLORS.get(rows[y][x], Color.TRANSPARENT))
	return ImageTexture.create_from_image(image)


# Centres what is built of the floor shown in the plan, scaled so it fills PLAN_FILL of the plan
# both ways at most. The First floor is built whole.
func _place_building() -> void:
	var built := Rect2(0.0, 0.0, 1.0, 1.0) if _upstairs.visible else _ground_built
	var built_m := built.size * FLOOR_M
	var px_per_m := minf(_plan.size.x * PLAN_FILL / built_m.x, _plan.size.y * PLAN_FILL / built_m.y)
	_building.size = FLOOR_M * px_per_m
	_building.position = (_plan.size / 2.0 - built.get_center() * _building.size).floor()


# Draws a room by `look`: its fill, its `furniture`, then its walls centred on its edges, so
# neighbours share them, with gaps for `doors`. `area` is where the room is on its floor, as
# fractions; a swatch has none, so it draws thin plain walls inside its edges.
func _paint(item: Control, look: int, area: Rect2, doors: Dictionary[Vector2, String], furniture: String) -> void:
	var rect := Rect2(Vector2.ZERO, item.size)
	if not rect.has_area():
		return
	var swatch := not area.has_area()
	var ink := WALL
	var wall_px := THIN_WALL_PX if swatch else WALL_PX
	var dashed := false
	match look:
		Look.IN_USE:
			# A swatch is small, so its fill is stronger to read as one.
			item.draw_rect(rect, Color(WALL, 0.16 if swatch else 0.08))
		Look.DAMAGED:
			item.draw_rect(rect, Color(WALL, 0.05))
			_hatch(item, rect)
			ink = Color(WALL, 0.45)
			wall_px = THIN_WALL_PX
			dashed = true
		Look.RESTORING, Look.CONVERTING:
			ink = WORK
	var px_per_m := 0.0 if swatch else item.get_parent_control().size.x / FLOOR_M.x
	if not furniture.is_empty():
		_furnish(item, FURNITURE[furniture], rect, px_per_m)
	if swatch:
		rect = rect.grow(-wall_px / 2.0)
	var ground := (_plan.get_theme_stylebox(&"panel") as StyleBoxFlat).bg_color
	var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	var spots: Array[Vector2] = [area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)]
	for i: int in corners.size():
		var a := corners[i]
		var b := corners[(i + 1) % corners.size()]
		var length := a.distance_to(b)
		# Each doorway as its start and end in pixels along the edge.
		var gaps: Array[Vector2] = []
		for door: Vector2 in doors:
			var t := _along(door, spots[i], spots[(i + 1) % spots.size()])
			if t > 0.0 and _rooms[doors[door]].look != Look.UNBUILT:
				gaps.append(Vector2(t * length - DOOR_M * px_per_m / 2.0, t * length + DOOR_M * px_per_m / 2.0))
		gaps.sort()
		var along := (b - a) / length
		var across := Vector2(-along.y, along.x) * WALL_PX / 2.0
		# A wall runs on past the room's corners by half its width, to close the corner.
		var at := -wall_px / 2.0
		for gap: Vector2 in gaps:
			_wall(item, a + along * at, a + along * gap.x, ink, wall_px, dashed)
			# The doorway's threshold shows the plan's ground.
			var start := a + along * gap.x
			var end := a + along * gap.y
			item.draw_colored_polygon(PackedVector2Array([start - across, end - across, end + across, start + across]), ground)
			at = gap.y
		_wall(item, a + along * at, b + along * wall_px / 2.0, ink, wall_px, dashed)


func _wall(item: Control, from: Vector2, to: Vector2, ink: Color, width: float, dashed: bool) -> void:
	if dashed:
		item.draw_dashed_line(from, to, ink, width, DASH_PX)
	else:
		item.draw_line(from, to, ink, width)


# Draws `pieces` of FURNITURE in `rect`, at `px_per_m`.
func _furnish(item: Control, pieces: Array, rect: Rect2, px_per_m: float) -> void:
	for piece: Array in pieces:
		var origin: Vector2 = rect.position + rect.size * (piece[1] as Vector2)
		match piece[0]:
			"box", "frame", "slab":
				var shape: Rect2 = piece[2]
				var box := Rect2(origin + shape.position * px_per_m, shape.size * px_per_m)
				if piece[0] != "frame":
					item.draw_rect(box, FURNITURE_INK if piece[0] == "slab" else FURNITURE_FILL)
				if piece[0] != "slab":
					item.draw_rect(box, FURNITURE_INK, false, FURNITURE_PX)
			"line":
				item.draw_line(origin + piece[2] * px_per_m, origin + piece[3] * px_per_m, FURNITURE_INK, FURNITURE_PX)
			"dash":
				item.draw_dashed_line(origin + piece[2] * px_per_m, origin + piece[3] * px_per_m, FURNITURE_INK, FURNITURE_PX, FURNITURE_DASH_PX)
			"seat", "disc":
				var centre: Vector2 = origin + piece[2] * px_per_m
				var radius: float = piece[3] * px_per_m
				if piece[0] == "disc":
					item.draw_circle(centre, radius, FURNITURE_FILL, true, -1.0, true)
				item.draw_arc(centre, radius, 0.0, TAU, 32, FURNITURE_INK, FURNITURE_PX, true)
			"arc":
				item.draw_arc(origin + piece[2] * px_per_m, piece[3] * px_per_m, piece[4], piece[5], 16, FURNITURE_INK, FURNITURE_PX, true)


# How far along the edge `from`–`to` the point `spot` is, from 0 to 1; -1 when it is not on it.
static func _along(spot: Vector2, from: Vector2, to: Vector2) -> float:
	var axis := 1 if is_equal_approx(from.y, to.y) else 0
	if not is_equal_approx(spot[axis], from[axis]):
		return -1.0
	var t := (spot[1 - axis] - from[1 - axis]) / (to[1 - axis] - from[1 - axis])
	return t if t > 0.0 and t < 1.0 else -1.0


# Thin pale diagonal lines rising to the right, HATCH_STEP_PX apart, kept inside `rect`.
func _hatch(item: Control, rect: Rect2) -> void:
	var lines := PackedVector2Array()
	# Lines x + y = reach are HATCH_STEP_PX apart when `reach` steps by √2 times that.
	var step := HATCH_STEP_PX * sqrt(2.0)
	var reach := step
	while reach < rect.size.x + rect.size.y:
		# The line x + y = reach, from where it enters `rect` to where it leaves.
		lines.append(Vector2(maxf(0.0, reach - rect.size.y), minf(rect.size.y, reach)))
		lines.append(Vector2(minf(rect.size.x, reach), maxf(0.0, reach - rect.size.x)))
		reach += step
	item.draw_multiline(lines, HATCH, HATCH_PX)


# A room's look as a small square, for the legend and the In progress rows.
func _swatch(look: Look, size_px: Vector2) -> Control:
	var swatch := Control.new()
	swatch.custom_minimum_size = size_px
	swatch.clip_contents = true
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.draw.connect(func() -> void: _paint(swatch, look, Rect2(), {}, ""))
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
	bar.custom_minimum_size = Vector2(0, BAR_PX)
	return bar


func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.theme_type_variation = variation
	return label
