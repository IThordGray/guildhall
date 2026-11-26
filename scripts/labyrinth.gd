class_name Labyrinth
extends RefCounted

## The labyrinth under the guild: floors a party explores bit by bit, each bringing back its own
## material. Each floor is a quest in Dispatch.QUESTS with a "floor" number, so its chance, damage,
## XP, gold, loot, tries and reputation are a quest's; what a party home from it adds here is the
## floor's own. Numbers are stand-ins.

## What Goals unlocks to open the labyrinth's first floor.
const UNLOCK: String = "labyrinth"
## Each floor, by its quest id in Dispatch.QUESTS: "material", what a party brings back from it, and
## "clear_bonus", the gold the guild earns the first time it is fully explored.
const FLOORS: Dictionary[String, Dictionary] = {
	"floor_1": {"material": "Glowmoss", "clear_bonus": 60},
	"floor_2": {"material": "Riverglass", "clear_bonus": 100},
	"floor_3": {"material": "Bone silver", "clear_bonus": 200},
}
## How much of a floor, in percent, a party home from it explores, and how much of its material it
## brings, on a success and on a failure. Explored never goes past 100.
const SUCCESS_EXPLORED: int = 20
const FAILURE_EXPLORED: int = 5
const SUCCESS_MATERIAL: int = 3
const FAILURE_MATERIAL: int = 1
## How much of a floor, in percent, must be explored before the floor below it opens.
const NEXT_FLOOR_AT: int = 50

## How much of each floor is explored, in whole percent, by its quest id; a floor missing is at 0.
var explored: Dictionary[String, int] = {}
## How much of each material the guild holds, by its name. Materials are kept apart from the stash.
var materials: Dictionary[String, int] = {}


## How much of floor `floor_id` is explored, in whole percent.
func explored_percent(floor_id: String) -> int:
	return explored.get(floor_id, 0)


## Adds what a party home from floor `floor_id` brings, by whether it was a `success`: explored
## percent and material. The first time the floor reaches 100% its clear bonus goes into `gold`; as
## explored never goes back, that is once ever.
func bring_home(floor_id: String, success: bool, gold: Gold) -> void:
	var before := explored_percent(floor_id)
	explored[floor_id] = mini(100, before + (SUCCESS_EXPLORED if success else FAILURE_EXPLORED))
	var material: String = FLOORS[floor_id]["material"]
	materials[material] = int(materials.get(material, 0)) + (SUCCESS_MATERIAL if success else FAILURE_MATERIAL)
	if before < 100 and explored[floor_id] == 100:
		gold.earn(int(FLOORS[floor_id]["clear_bonus"]))


## Puts the labyrinth into `file`, which other state shares, so one save holds the whole game.
func write(file: ConfigFile) -> void:
	file.set_value("labyrinth", "explored", explored)
	file.set_value("labyrinth", "materials", materials)


## The labyrinth saved at `path`; nothing explored and no materials when the save has none, as one
## from before the labyrinth.
static func load_or_start(path: String) -> Labyrinth:
	var labyrinth := Labyrinth.new()
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return labyrinth
	labyrinth.explored.assign(file.get_value("labyrinth", "explored", {}))
	labyrinth.materials.assign(file.get_value("labyrinth", "materials", {}))
	return labyrinth
