class_name Gold
extends RefCounted

## Gold held. It changes only by quest rewards and spending, never with time, so a clock set back
## can't change it.
var amount: int


func _init(start_gold: int) -> void:
	amount = start_gold


## Takes `cost`, or nothing when less than `cost` is held; true when paid.
func spend(cost: int) -> bool:
	if amount < cost:
		return false
	amount -= cost
	return true


## Puts the gold into `file`, which other state shares, so one save holds the whole game.
func write(file: ConfigFile) -> void:
	file.set_value("gold", "saved", amount)


## The gold saved at `path`, or a new game's 0 when there is none.
static func load_or_start(path: String) -> Gold:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return Gold.new(0)
	return Gold.new(int(file.get_value("gold", "saved", 0)))
