class_name Hall
extends RefCounted

enum State { USABLE, DAMAGED, RESTORING, RESTORED }

const RESTORE_COST_GOLD: int = 120
const RESTORE_SECONDS: int = 120
## Rooms usable from the start; every other slot starts damaged.
const STARTING_USABLE: Array[String] = ["entrance", "reception"]

## Slots the builder has finished restoring.
var restored: PackedStringArray = PackedStringArray()
## The slot being restored, or "" when the builder is free. One builder, so one at a time.
var restoring: String = ""
## Unix seconds the current restoration started.
var restoring_since: int = 0
## Latest unix seconds seen. Time is read as never earlier than this, so a clock set back
## neither adds time to a countdown nor un-restores a room.
var checked_at: int


func _init(at: int) -> void:
	checked_at = at


func state(slot: String, now: int) -> State:
	if slot in STARTING_USABLE:
		return State.USABLE
	if slot in restored:
		return State.RESTORED
	if slot == restoring:
		return State.RESTORED if seconds_left(now) == 0 else State.RESTORING
	return State.DAMAGED


## Seconds until the current restoration finishes; 0 when it has finished or none is running.
func seconds_left(now: int) -> int:
	if restoring.is_empty():
		return 0
	return maxi(0, restoring_since + RESTORE_SECONDS - maxi(now, checked_at))


## Why `slot` can't be restored at `now`, in words for the player; "" when it can.
func refusal(slot: String, gold: Gold, now: int) -> String:
	if state(slot, now) != State.DAMAGED:
		return "Not damaged"
	if seconds_left(now) > 0:
		return "Builder busy"
	var short_gold := RESTORE_COST_GOLD - gold.amount
	if short_gold > 0:
		return "Need %d more gold" % short_gold
	return ""


## Pays and starts restoring `slot` at `now`; false, with nothing paid, when `refusal` gives a reason.
func restore(slot: String, gold: Gold, now: int) -> bool:
	if not refusal(slot, gold, now).is_empty():
		return false
	checkpoint(now)
	gold.spend(RESTORE_COST_GOLD)
	restoring = slot
	restoring_since = checked_at
	return true


## True when a restoration finished after the last checkpoint: the "while you were away" news when
## the checkpoint was taken on leaving.
func finished_since_checkpoint(now: int) -> bool:
	return not restoring.is_empty() and seconds_left(now) == 0


## Records a finished restoration as restored for good, and the time seen.
func checkpoint(now: int) -> void:
	checked_at = maxi(checked_at, now)
	if finished_since_checkpoint(checked_at):
		restored.append(restoring)
		restoring = ""


## Puts the hall into `file`, which other state shares, so one save holds the whole game.
func write(file: ConfigFile) -> void:
	file.set_value("hall", "restored", restored)
	file.set_value("hall", "restoring", restoring)
	file.set_value("hall", "restoring_since", restoring_since)
	file.set_value("hall", "checked_at", checked_at)


## The hall saved at `path`, or a fresh one at `now` when the save has none.
static func load_or_start(path: String, now: int) -> Hall:
	var hall := Hall.new(now)
	var file := ConfigFile.new()
	if file.load(path) != OK or not file.has_section("hall"):
		return hall
	hall.restored = file.get_value("hall", "restored", PackedStringArray())
	hall.restoring = file.get_value("hall", "restoring", "")
	hall.restoring_since = int(file.get_value("hall", "restoring_since", 0))
	hall.checked_at = int(file.get_value("hall", "checked_at", now))
	return hall
