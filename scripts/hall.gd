class_name Hall
extends RefCounted

## UNBUILT is a First floor room before the First floor is built.
enum State { USABLE, DAMAGED, RESTORING, RESTORED, CONVERTING, CONVERTED, UNBUILT }

## What restoring a room costs and takes, by the order rooms are restored in: the first room the
## first entry, and so on; any after the last, the last (stand-ins). Cheap and quick first.
const RESTORES: Array[Dictionary] = [
	{"gold": 60, "seconds": 30},
	{"gold": 120, "seconds": 120},
	{"gold": 200, "seconds": 300},
	{"gold": 300, "seconds": 600},
]
## Rooms usable from the start; every other slot starts damaged.
const STARTING_USABLE: Array[String] = ["entrance", "reception"]
## Extending the hall builds the First floor: what it costs and takes, done by the builder like a
## restoration, and how many rooms must be restored first (stand-ins).
const EXTEND_GOLD: int = 400
const EXTEND_SECONDS: int = 600
const EXTEND_AFTER_RESTORES: int = 3
## The First floor's rooms. They are new, so they start restored and empty once it is built.
const FIRST_FLOOR: Array[String] = ["upper_nw", "upper_ne", "upper_sw", "upper_se"]
## What `building` holds while the builder extends the hall; not a slot.
const EXTENSION: String = "first_floor"
## What an empty restored room can be converted into, in panel order. The save and the art refer
## to a type by its id. What a type does is applied where its effect is: see Dispatch.
const ROOM_TYPES: Dictionary[String, Dictionary] = {
	"quest_hall": {"name": "Quest hall", "blurb": "adds a slot to the quest board", "gold": 60, "seconds": 60},
	"infirmary": {"name": "Infirmary", "blurb": "injuries heal twice as fast", "gold": 60, "seconds": 60},
	"bunk_room": {"name": "Bunk room", "blurb": "2 more beds", "gold": 60, "seconds": 60},
	"tavern": {"name": "Tavern", "blurb": "earns gold while you're away", "gold": 60, "seconds": 60},
	"map_room": {"name": "Map room", "blurb": "reveals quests' unknown challenges", "gold": 60, "seconds": 60},
	"training_room": {"name": "Training room", "blurb": "trains one adventurer at a time", "gold": 60, "seconds": 60},
	"common_room": {"name": "Common room", "blurb": "more candidates visit", "gold": 60, "seconds": 60},
}
## A finished Tavern fills with gold at this rate from when it finished or was last collected, up
## to TAVERN_CAP; the cap is the reason to come back before it is full (stand-ins).
const TAVERN_GOLD_PER_MINUTE: int = 2
const TAVERN_CAP: int = 120
## Beds the guild has with no Bunk room; each finished one adds BEDS_PER_BUNK_ROOM.
const STARTING_BEDS: int = 4
const BEDS_PER_BUNK_ROOM: int = 2
## The most adventurers the guild can have, however many Bunk rooms it has.
const MAX_ROSTER: int = 8

## Slots the builder has finished restoring, converted or not.
var restored: PackedStringArray = PackedStringArray()
## Whether the builder has finished extending the hall.
var first_floor: bool = false
## Rooms the builder has finished converting: slot -> {"type": a ROOM_TYPES id, "done_at": unix
## seconds the conversion finished, and for a Tavern collected at least once "collected_at": unix
## seconds it was last collected}.
var converted: Dictionary[String, Dictionary] = {}
## The slot the builder is working on, or "" when the builder is free. One builder, so one
## restoration, conversion or extension at a time.
var building: String = ""
## Unix seconds the builder started on `building`.
var building_since: int = 0
## The room type `building` is being converted into; "" when it is being restored.
var building_into: String = ""
## Latest unix seconds seen. Time is read as never earlier than this, so a clock set back
## neither adds time to a countdown nor undoes a restoration or a conversion.
var checked_at: int


func _init(at: int) -> void:
	checked_at = at


func state(slot: String, now: int) -> State:
	if slot in STARTING_USABLE:
		return State.USABLE
	if slot == building:
		var done := seconds_left(now) == 0
		if building_into.is_empty():
			return State.RESTORED if done else State.RESTORING
		return State.CONVERTED if done else State.CONVERTING
	if slot in converted:
		return State.CONVERTED
	if slot in restored:
		return State.RESTORED
	if slot in FIRST_FLOOR:
		return State.RESTORED if has_first_floor(now) else State.UNBUILT
	return State.DAMAGED


## Whether the First floor is built by `now`; an extension under way counts once finished.
func has_first_floor(now: int) -> bool:
	return first_floor or (building == EXTENSION and seconds_left(now) == 0)


## The type `slot` is converted, or being converted, into; "" for none.
func room_type(slot: String) -> String:
	if slot == building:
		return building_into
	return converted.get(slot, {}).get("type", "")


## How many rooms of `type` are converted by `now`; one under way counts once finished.
func rooms_done(type: String, now: int) -> int:
	var count := 0
	for room: Dictionary in converted.values():
		if room["type"] == type:
			count += 1
	if building_into == type and seconds_left(now) == 0:
		count += 1
	return count


## How many adventurers the guild has beds for at `now`.
func beds(now: int) -> int:
	return mini(MAX_ROSTER, STARTING_BEDS + BEDS_PER_BUNK_ROOM * rooms_done("bunk_room", now))


## The slot of the first room of `type` to be converted, on any floor, counting one under way,
## whose end is fixed when it starts; "" when there is none.
func first_room(type: String) -> String:
	var first := ""
	for slot: String in converted:
		if converted[slot]["type"] == type and (first.is_empty() or int(converted[slot]["done_at"]) < int(converted[first]["done_at"])):
			first = slot
	# A room under way finishes after every converted one, so it is first only when alone.
	if building_into == type and first.is_empty():
		first = building
	return first


## Unix seconds the first room of `type` is converted at, as `first_room`; -1 when there is none.
func first_done_at(type: String) -> int:
	var first := first_room(type)
	if first.is_empty():
		return -1
	return _done_at() if first == building else int(converted[first]["done_at"])


## The gold the Tavern in `slot` holds at `now`: TAVERN_GOLD_PER_MINUTE for each minute since it
## finished or was last collected, up to TAVERN_CAP; 0 for any other room. Computed from saved
## times alone, so being away gives the same as watching.
func tavern_gold(slot: String, now: int) -> int:
	if room_type(slot) != "tavern" or state(slot, now) != State.CONVERTED:
		return 0
	var since: int = _done_at() if slot == building else int(converted[slot].get("collected_at", converted[slot]["done_at"]))
	return mini(TAVERN_CAP, (maxi(now, checked_at) - since) * TAVERN_GOLD_PER_MINUTE / 60)


## Moves all the gold the Tavern in `slot` holds at `now` into `gold` and starts it filling again
## from then; the amount moved. An empty room gives 0 and is left as it was.
func collect(slot: String, gold: Gold, now: int) -> int:
	var amount := tavern_gold(slot, now)
	if amount == 0:
		return 0
	# A Tavern finished since the last checkpoint is among the converted rooms after it.
	checkpoint(now)
	converted[slot]["collected_at"] = checked_at
	gold.amount += amount
	return amount


## Seconds until the builder's current job finishes; 0 when it has finished or none is running.
func seconds_left(now: int) -> int:
	if building.is_empty():
		return 0
	return maxi(0, _done_at() - maxi(now, checked_at))


## Why `slot` can't be restored at `now`, in words for the player; "" when it can.
func refusal(slot: String, gold: Gold, now: int) -> String:
	if state(slot, now) != State.DAMAGED:
		return "Not damaged"
	return _builder_refusal(next_restore()["gold"], gold, now)


## Pays and starts restoring `slot` at `now`; false, with nothing paid, when `refusal` gives a reason.
func restore(slot: String, gold: Gold, now: int) -> bool:
	if not refusal(slot, gold, now).is_empty():
		return false
	_start(slot, "", next_restore()["gold"], gold, now)
	return true


## What the next restoration costs and takes, {"gold", "seconds"} from RESTORES: the rooms
## restored and one under way come before it.
func next_restore() -> Dictionary:
	var before := restored.size()
	if _restoring():
		before += 1
	return _restore_after(before)


## How many seconds the builder's current job takes in all.
func job_seconds() -> int:
	if building == EXTENSION:
		return EXTEND_SECONDS
	if building_into.is_empty():
		# The room under way is not yet among those restored.
		return _restore_after(restored.size())["seconds"]
	return ROOM_TYPES[building_into]["seconds"]


# Whether the builder's current job is a restoration.
func _restoring() -> bool:
	return not building.is_empty() and building != EXTENSION and building_into.is_empty()


# What restoring a room costs and takes once `before` rooms are restored.
static func _restore_after(before: int) -> Dictionary:
	return RESTORES[mini(before, RESTORES.size() - 1)]


## Why `slot` can't be converted into `type` at `now`, in words for the player; "" when it can.
func convert_refusal(slot: String, type: String, gold: Gold, now: int) -> String:
	if state(slot, now) != State.RESTORED:
		return "Not an empty room"
	return _builder_refusal(ROOM_TYPES[type]["gold"], gold, now)


## Pays and starts converting `slot` into `type` at `now`; false, with nothing paid, when
## `convert_refusal` gives a reason.
func convert_room(slot: String, type: String, gold: Gold, now: int) -> bool:
	if not convert_refusal(slot, type, gold, now).is_empty():
		return false
	_start(slot, type, ROOM_TYPES[type]["gold"], gold, now)
	return true


## Why the hall can't be extended at `now`, in words for the player; "" when it can.
func extend_refusal(gold: Gold, now: int) -> String:
	if first_floor or building == EXTENSION:
		return "Already extended"
	# A restoration finished since the last checkpoint is not yet among those restored.
	var restores := restored.size() + (1 if _restoring() and seconds_left(now) == 0 else 0)
	if restores < EXTEND_AFTER_RESTORES:
		return "Restore the ground floor first"
	return _builder_refusal(EXTEND_GOLD, gold, now)


## Pays and starts extending the hall at `now`; false, with nothing paid, when `extend_refusal`
## gives a reason.
func extend(gold: Gold, now: int) -> bool:
	if not extend_refusal(gold, now).is_empty():
		return false
	_start(EXTENSION, "", EXTEND_GOLD, gold, now)
	return true


## True when the builder finished a job after the last checkpoint: the "while you were away" news
## when the checkpoint was taken on leaving.
func finished_since_checkpoint(now: int) -> bool:
	return not building.is_empty() and seconds_left(now) == 0


## Records a finished job as restored, converted or extended for good, and the time seen.
func checkpoint(now: int) -> void:
	checked_at = maxi(checked_at, now)
	if finished_since_checkpoint(checked_at):
		if building == EXTENSION:
			first_floor = true
		elif building_into.is_empty():
			restored.append(building)
		else:
			converted[building] = {"type": building_into, "done_at": _done_at()}
		building = ""
		building_into = ""


func _builder_refusal(cost: int, gold: Gold, now: int) -> String:
	if seconds_left(now) > 0:
		return "Builder busy"
	var short_gold := cost - gold.amount
	if short_gold > 0:
		return "Need %d more gold" % short_gold
	return ""


func _start(slot: String, into: String, cost: int, gold: Gold, now: int) -> void:
	checkpoint(now)
	gold.spend(cost)
	building = slot
	building_into = into
	building_since = checked_at


func _done_at() -> int:
	return building_since + job_seconds()


## Puts the hall into `file`, which other state shares, so one save holds the whole game.
## The builder's job keeps the keys it had when it could only restore, so older saves still load.
func write(file: ConfigFile) -> void:
	file.set_value("hall", "restored", restored)
	file.set_value("hall", "converted", converted)
	file.set_value("hall", "restoring", building)
	file.set_value("hall", "restoring_since", building_since)
	file.set_value("hall", "converting_into", building_into)
	file.set_value("hall", "first_floor", first_floor)
	file.set_value("hall", "checked_at", checked_at)


## The hall saved at `path`, or a fresh one at `now` when the save has none.
static func load_or_start(path: String, now: int) -> Hall:
	var hall := Hall.new(now)
	var file := ConfigFile.new()
	if file.load(path) != OK or not file.has_section("hall"):
		return hall
	hall.restored = file.get_value("hall", "restored", PackedStringArray())
	hall.converted.assign(file.get_value("hall", "converted", {}))
	hall.building = file.get_value("hall", "restoring", "")
	hall.building_since = int(file.get_value("hall", "restoring_since", 0))
	hall.building_into = file.get_value("hall", "converting_into", "")
	hall.first_floor = file.get_value("hall", "first_floor", false)
	hall.checked_at = int(file.get_value("hall", "checked_at", now))
	return hall
