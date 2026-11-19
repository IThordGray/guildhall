class_name Gold
extends RefCounted

## Gold earns at this rate on wall-clock time, open or closed.
const PER_SECOND: int = 1

## Gold held at `saved_at`.
var saved: int
## Unix seconds of the snapshot. It never moves backwards, so a clock set back adds and removes nothing.
var saved_at: int


func _init(start_gold: int, at: int) -> void:
	saved = start_gold
	saved_at = at


## Gold held at `now`: the snapshot plus what accrued since. A clock behind the snapshot adds nothing.
func amount(now: int) -> int:
	return saved + PER_SECOND * maxi(0, now - saved_at)


## Gold accrued since the last checkpoint: the "while you were away" amount when the checkpoint was taken on leaving.
func gained_since_checkpoint(now: int) -> int:
	return amount(now) - saved


## Shorter absences pass without a "while you were away" message.
const AWAY_NOTICE_AFTER_SECONDS: int = 30


## The gold to report on return: what accrued since the last checkpoint, or 0 when the absence lasted
## no more than AWAY_NOTICE_AFTER_SECONDS.
func away_report(now: int) -> int:
	if now - saved_at <= AWAY_NOTICE_AFTER_SECONDS:
		return 0
	return gained_since_checkpoint(now)


## Folds what accrued up to `now` into the snapshot; the total stays the same.
func checkpoint(now: int) -> void:
	saved = amount(now)
	saved_at = maxi(saved_at, now)


func save(path: String) -> Error:
	var file := ConfigFile.new()
	file.set_value("gold", "saved", saved)
	file.set_value("gold", "saved_at", saved_at)
	return file.save(path)


## The snapshot saved at `path`, or a new game with no gold starting at `now` when there is none.
static func load_or_start(path: String, now: int) -> Gold:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return Gold.new(0, now)
	return Gold.new(int(file.get_value("gold", "saved", 0)), int(file.get_value("gold", "saved_at", now)))
