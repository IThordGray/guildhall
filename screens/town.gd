class_name TownScreen
extends Control

## The town beyond the guild hall, shown in the hall's place: a plan of its two streets and the
## places the guild can visit, each drawn as a room in use. For now, only the Market.

## The player switched back to the guild hall.
signal hall_pressed
## The player tapped the Market, to visit it.
signal market_pressed

## Two streets cross in the middle of the plan, round a roundabout.
const STREET_PX: float = 94.0
const ROUNDABOUT_RADIUS_PX: float = 80.0
const ROUNDABOUT_RING_PX: float = 6.0
const STREET: Color = Color("#24202c")
const ROUNDABOUT: Color = Color("#3a3446")
## The Market's size on the plan; it stands in the middle of the block north-west of the crossing.
const MARKET_PX: Vector2 = Vector2(354, 310)
## The Market's icon in the room's bottom-right corner: a stall under an awning, with a door, as
## strokes on a 24-unit grid drawn ICON_PX across, in gold.
const ICON_PX: float = 94.0
const ICON_INSET_PX: float = 22.0
const ICON_STROKE_PX: float = 7.0
const ICON_GOLD: Color = Color("#f2c14e")
const ICON_GRID: float = 24.0
const ICON_STROKES: Array = [
	[Vector2(4, 9), Vector2(20, 9), Vector2(18.5, 4), Vector2(5.5, 4), Vector2(4, 9)],
	[Vector2(5, 9), Vector2(5, 20), Vector2(19, 20), Vector2(19, 9)],
	[Vector2(10, 20), Vector2(10, 14), Vector2(14, 14), Vector2(14, 20)],
]

@onready var _parties: Control = $Box/Header/Parties
@onready var _parties_count: Label = $Box/Header/Parties/Count
@onready var _plan: Control = $Box/Plan
@onready var _market: Button = $Box/Plan/Market


func _ready() -> void:
	var town_button := $Box/Header/Switch/Row/Town as Button
	($Box/Header/Switch/Row/Hall as Button).pressed.connect(func() -> void:
		town_button.button_pressed = true
		hall_pressed.emit())
	_market.pressed.connect(market_pressed.emit)
	_market.draw.connect(_draw_market)
	_market.size = MARKET_PX
	_plan.draw.connect(_draw_streets)
	_plan.resized.connect(_place_market)


## Landscape shows how many parties are out beside the title.
func set_landscape(landscape: bool) -> void:
	_parties.visible = landscape


## Shows the town with `parties_out` parties out.
func show_town(parties_out: int) -> void:
	_parties_count.text = str(parties_out)


# Centres the Market in the block between the plan's top-left corner and the streets.
func _place_market() -> void:
	var block := (_plan.size - Vector2(STREET_PX, STREET_PX)) / 2.0
	_market.position = ((block - MARKET_PX) / 2.0).floor()


func _draw_streets() -> void:
	var middle := _plan.size / 2.0
	_plan.draw_rect(Rect2(0.0, middle.y - STREET_PX / 2.0, _plan.size.x, STREET_PX), STREET)
	_plan.draw_rect(Rect2(middle.x - STREET_PX / 2.0, 0.0, STREET_PX, _plan.size.y), STREET)
	_plan.draw_arc(middle, ROUNDABOUT_RADIUS_PX, 0.0, TAU, 48, ROUNDABOUT, ROUNDABOUT_RING_PX, true)


# The Market as a room in use on the hall's plan: a faint fill inside full walls, and its icon.
func _draw_market() -> void:
	var rect := Rect2(Vector2.ZERO, _market.size)
	_market.draw_rect(rect, Color(HallView.WALL, 0.08))
	_market.draw_rect(rect.grow(-HallView.WALL_PX / 2.0), HallView.WALL, false, HallView.WALL_PX)
	var origin := rect.end - Vector2(ICON_INSET_PX + ICON_PX, ICON_INSET_PX + ICON_PX)
	for stroke: Array in ICON_STROKES:
		var points := PackedVector2Array()
		for point: Vector2 in stroke:
			points.append(origin + point * ICON_PX / ICON_GRID)
		_market.draw_polyline(points, ICON_GOLD, ICON_STROKE_PX, true)
