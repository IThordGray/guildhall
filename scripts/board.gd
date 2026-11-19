class_name Board
extends RefCounted

## How many quests each local day's board has without a Quest hall; each finished one adds one.
const QUESTS_A_DAY: int = 3
const SECONDS_A_DAY: int = 86_400

## The local day `used` belongs to, in days since 1970-01-01.
var day: int = 0
## Quests sent on `day`. A quest sent stays off the board until the next local day.
var used: PackedStringArray = PackedStringArray()


## The local day `unix_seconds` falls on, in days since 1970-01-01, for a device
## `utc_offset_minutes` ahead of UTC.
static func day_of(unix_seconds: int, utc_offset_minutes: int) -> int:
	return floori((unix_seconds + utc_offset_minutes * 60) / float(SECONDS_A_DAY))


## Every quest in the order `local_day` offers them, fixed by the day alone: a board of N quests
## shows the first N, so a Quest hall finished mid-day adds one without changing the others.
static func order_of(local_day: int) -> PackedStringArray:
	var order := PackedStringArray(Dispatch.QUESTS.keys())
	var rng := RandomNumberGenerator.new()
	rng.seed = local_day
	for i: int in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swapped := order[i]
		order[i] = order[j]
		order[j] = swapped
	return order


## The quests on the board at `now`, in board order, with `quest_halls` Quest halls finished: the
## local day's, less those sent that day and those still out. The day is read from no earlier
## than `dispatch` last saw, so a clock set back never brings back an earlier day's board.
func quests(dispatch: Dispatch, now: int, utc_offset_minutes: int, quest_halls: int) -> PackedStringArray:
	var today := day_of(maxi(now, dispatch.checked_at), utc_offset_minutes)
	var out := PackedStringArray()
	for outing: Dictionary in dispatch.outings:
		out.append(outing["quest"])
	var shown := PackedStringArray()
	for quest: String in order_of(today).slice(0, QUESTS_A_DAY + quest_halls):
		if not (today == day and quest in used) and quest not in out:
			shown.append(quest)
	return shown


## Sends `party` on `quest` through `dispatch` and takes the quest off the board for the rest of
## the local day; false, with nothing sent, when the board at `now` doesn't show it or `dispatch`
## refuses the party. The other arguments are as for `quests` and `Dispatch.send`.
func send(dispatch: Dispatch, quest: String, party: PackedStringArray, roll_seed: int, gold: Gold, now: int, utc_offset_minutes: int, quest_halls: int, infirmary_from: int = -1) -> bool:
	# A party back by now no longer holds its quest off the board.
	dispatch.checkpoint(now, gold, infirmary_from)
	if quest not in quests(dispatch, now, utc_offset_minutes, quest_halls):
		return false
	if not dispatch.send(quest, party, roll_seed, gold, now, infirmary_from):
		return false
	var today := day_of(dispatch.checked_at, utc_offset_minutes)
	if today != day:
		day = today
		used = PackedStringArray()
	used.append(quest)
	return true


## Puts the board into `file`, which other state shares, so one save holds the whole game.
func write(file: ConfigFile) -> void:
	file.set_value("board", "day", day)
	file.set_value("board", "used", used)


## The board saved at `path`, or one with nothing used when the save has none.
static func load_or_start(path: String) -> Board:
	var board := Board.new()
	var file := ConfigFile.new()
	if file.load(path) != OK or not file.has_section("board"):
		return board
	board.day = int(file.get_value("board", "day", 0))
	board.used = file.get_value("board", "used", PackedStringArray())
	return board
