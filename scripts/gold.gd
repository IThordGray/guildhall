class_name Gold
extends RefCounted

## The gold a new game starts with: enough for the first restoration.
const STARTING_GOLD: int = 100

## Gold held. It changes only by income (`earn`), selling from the stash and spending, never with
## time, so a clock set back can't change it.
var amount: int
## All the gold income has ever brought (`earn`): not the starting gold, nor selling.
var earned: int = 0


func _init(start_gold: int) -> void:
	amount = start_gold


## Adds `gold` of income: quest and expedition rewards, a floor's clear bonus, goal claims and
## Tavern collections. Counted in `earned` too.
func earn(gold: int) -> void:
	amount += gold
	earned += gold


## Takes `cost`, or nothing when less than `cost` is held; true when paid.
func spend(cost: int) -> bool:
	if amount < cost:
		return false
	amount -= cost
	return true


## Puts the gold into `file`, which other state shares, so one save holds the whole game.
func write(file: ConfigFile) -> void:
	file.set_value("gold", "saved", amount)
	file.set_value("gold", "earned", earned)


## The gold saved at `path`, or a new game's STARTING_GOLD when there is none. A save from before
## gold earned was counted has earned none.
static func load_or_start(path: String) -> Gold:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return Gold.new(STARTING_GOLD)
	var gold := Gold.new(int(file.get_value("gold", "saved", 0)))
	gold.earned = int(file.get_value("gold", "earned", 0))
	return gold
