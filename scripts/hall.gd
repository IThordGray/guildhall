class_name Hall
extends RefCounted

enum State { USABLE, DAMAGED, RESTORING, RESTORED, CONVERTING, CONVERTED }

const RESTORE_COST_GOLD: int = 120
const RESTORE_SECONDS: int = 120
## Rooms usable from the start; every other slot starts damaged.
const STARTING_USABLE: Array[String] = ["entrance", "reception"]
## What an empty restored room can be converted into, in panel order. The save and the art refer
## to a type by its id. What a type does is applied where its effect is: see Dispatch.
const ROOM_TYPES: Dictionary[String, Dictionary] = {
	"quest_hall": {"name": "Quest hall", "blurb": "adds a quest to the board each day", "gold": 60, "seconds": 60},
	"infirmary": {"name": "Infirmary", "blurb": "injuries heal twice as fast", "gold": 60, "seconds": 60},
}

## Slots the builder has finished restoring, converted or not.
var restored: PackedStringArray = PackedStringArray()
## Rooms the builder has finished converting: slot -> {"type": a ROOM_TYPES id, "done_at": unix
## seconds the conversion finished}.
var converted: Dictionary[String, Dictionary] = {}
## The slot the builder is working on, or "" when the builder is free. One builder, so one
## restoration or conversion at a time.
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
	return State.DAMAGED


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


## Unix seconds the first room of `type` is converted at, counting one under way, whose end is
## fixed when it starts; -1 when there is none.
func first_done_at(type: String) -> int:
	var first := -1
	for room: Dictionary in converted.values():
		if room["type"] == type and (first < 0 or int(room["done_at"]) < first):
			first = int(room["done_at"])
	# A room under way finishes after every converted one, so it is first only when alone.
	if building_into == type and first < 0:
		first = _done_at()
	return first


## Seconds until the builder's current job finishes; 0 when it has finished or none is running.
func seconds_left(now: int) -> int:
	if building.is_empty():
		return 0
	return maxi(0, _done_at() - maxi(now, checked_at))


## Why `slot` can't be restored at `now`, in words for the player; "" when it can.
func refusal(slot: String, gold: Gold, now: int) -> String:
	if state(slot, now) != State.DAMAGED:
		return "Not damaged"
	return _builder_refusal(RESTORE_COST_GOLD, gold, now)


## Pays and starts restoring `slot` at `now`; false, with nothing paid, when `refusal` gives a reason.
func restore(slot: String, gold: Gold, now: int) -> bool:
	if not refusal(slot, gold, now).is_empty():
		return false
	_start(slot, "", RESTORE_COST_GOLD, gold, now)
	return true


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


## True when the builder finished a job after the last checkpoint: the "while you were away" news
## when the checkpoint was taken on leaving.
func finished_since_checkpoint(now: int) -> bool:
	return not building.is_empty() and seconds_left(now) == 0


## Records a finished job as restored or converted for good, and the time seen.
func checkpoint(now: int) -> void:
	checked_at = maxi(checked_at, now)
	if finished_since_checkpoint(checked_at):
		if building_into.is_empty():
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
	var seconds: int = RESTORE_SECONDS if building_into.is_empty() else ROOM_TYPES[building_into]["seconds"]
	return building_since + seconds


## Puts the hall into `file`, which other state shares, so one save holds the whole game.
## The builder's job keeps the keys it had when it could only restore, so older saves still load.
func write(file: ConfigFile) -> void:
	file.set_value("hall", "restored", restored)
	file.set_value("hall", "converted", converted)
	file.set_value("hall", "restoring", building)
	file.set_value("hall", "restoring_since", building_since)
	file.set_value("hall", "converting_into", building_into)
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
	hall.checked_at = int(file.get_value("hall", "checked_at", now))
	return hall
