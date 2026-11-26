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
## From the moment the guild reaches rank C, time is cut into periods of ELITE_EVERY seconds counted
## from 0 (a period is game seconds divided by ELITE_EVERY, rounded down). Each period starting at or
## after that moment opens one elite expedition (Dispatch.is_elite) on a floor drawn from
## `elite_seed` and the period alone, for ELITE_WINDOW seconds from the period's start, unless a party
## is sent on it, which takes it for that period. So being away gives the same elites as watching.
const ELITE_EVERY: int = 720
const ELITE_WINDOW: int = 240
## How much of its floor's material a party home from an elite brings on a success; a failure brings
## none, and an elite explores nothing.
const ELITE_MATERIAL: int = 3

## How much of each floor is explored, in whole percent, by its quest id; a floor missing is at 0.
var explored: Dictionary[String, int] = {}
## How much of each material the guild holds, by its name. Materials are kept apart from the stash.
var materials: Dictionary[String, int] = {}
## What each period's elite floor is drawn from, with the period, never the global generator.
var elite_seed: int = randi()
## The latest period whose elite a party was sent on, -1 for none: it is not open again in that
## period. Time is never read as going back, so no earlier period is ever asked about again.
var elite_taken: int = -1


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


## The period of game seconds `at` (ELITE_EVERY).
static func elite_period(at: int) -> int:
	return floori(at / float(ELITE_EVERY))


## The floor, by its quest id, whose elite opens in `period`: one of FLOORS, drawn from `elite_seed`
## and the period alone.
func elite_floor(period: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["elite", elite_seed, period])
	return FLOORS.keys()[rng.randi_range(0, FLOORS.size() - 1)]


## Adds what a party home from the elite on floor `floor_id` brings, by whether it was a `success`:
## ELITE_MATERIAL of the floor's material on a success, nothing on a failure.
func bring_home_elite(floor_id: String, success: bool) -> void:
	if success:
		var material: String = FLOORS[floor_id]["material"]
		materials[material] = int(materials.get(material, 0)) + ELITE_MATERIAL


## Puts the labyrinth into `file`, which other state shares, so one save holds the whole game.
func write(file: ConfigFile) -> void:
	file.set_value("labyrinth", "explored", explored)
	file.set_value("labyrinth", "materials", materials)
	file.set_value("labyrinth", "elite_seed", elite_seed)
	file.set_value("labyrinth", "elite_taken", elite_taken)


## The labyrinth saved at `path`; nothing explored and no materials when the save has none, as one
## from before the labyrinth, and no elite taken when it is from before elites.
static func load_or_start(path: String) -> Labyrinth:
	var labyrinth := Labyrinth.new()
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return labyrinth
	labyrinth.explored.assign(file.get_value("labyrinth", "explored", {}))
	labyrinth.materials.assign(file.get_value("labyrinth", "materials", {}))
	labyrinth.elite_seed = int(file.get_value("labyrinth", "elite_seed", labyrinth.elite_seed))
	labyrinth.elite_taken = int(file.get_value("labyrinth", "elite_taken", -1))
	return labyrinth
