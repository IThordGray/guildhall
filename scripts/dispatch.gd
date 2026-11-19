class_name Dispatch
extends RefCounted

## The quests on the board, in board order. The save refers to a quest by its id.
const QUESTS: Dictionary[String, Dictionary] = {
	"rats": {"name": "Rats in the cellar", "seconds": 60, "gold": 50},
	"moonherbs": {"name": "Gather moonherbs", "seconds": 180, "gold": 150},
	"goblins": {"name": "Goblin camp", "seconds": 600, "gold": 500},
}

## The quest the guild's one party is on, or "" when the party is home.
var quest: String = ""
## Unix seconds the party left on `quest`.
var quest_since: int = 0
## Latest unix seconds seen. Time is read as never earlier than this, so a clock set back neither
## adds time to a quest nor brings back one that has returned.
var checked_at: int


func _init(at: int) -> void:
	checked_at = at


## Seconds until the party returns; 0 when it has returned or is home.
func seconds_left(now: int) -> int:
	if quest.is_empty():
		return 0
	return maxi(0, quest_since + int(QUESTS[quest]["seconds"]) - maxi(now, checked_at))


## Why the party can't be sent on a quest at `now`, in words for the player; "" when it can.
func refusal(now: int) -> String:
	if seconds_left(now) > 0:
		return "Party is out"
	return ""


## Sends the party on `quest_id` at `now`; false, with nothing started, when `refusal` gives a reason.
func send(quest_id: String, gold: Gold, now: int) -> bool:
	if not refusal(now).is_empty():
		return false
	checkpoint(now, gold)
	quest = quest_id
	quest_since = checked_at
	return true


## True when the party returned after the last checkpoint: the "while you were away" news when the
## checkpoint was taken on leaving. Its reward is paid at the next checkpoint.
func returned_since_checkpoint(now: int) -> bool:
	return not quest.is_empty() and seconds_left(now) == 0


## Pays a returned party's reward into `gold`, once, and frees the party; records the time seen.
func checkpoint(now: int, gold: Gold) -> void:
	checked_at = maxi(checked_at, now)
	if returned_since_checkpoint(checked_at):
		gold.amount += int(QUESTS[quest]["gold"])
		quest = ""


## Puts the dispatch into `file`, which other state shares, so one save holds the whole game.
func write(file: ConfigFile) -> void:
	file.set_value("dispatch", "quest", quest)
	file.set_value("dispatch", "quest_since", quest_since)
	file.set_value("dispatch", "checked_at", checked_at)


## The dispatch saved at `path`, or a party at home at `now` when the save has none.
static func load_or_start(path: String, now: int) -> Dispatch:
	var dispatch := Dispatch.new(now)
	var file := ConfigFile.new()
	if file.load(path) != OK or not file.has_section("dispatch"):
		return dispatch
	dispatch.quest = file.get_value("dispatch", "quest", "")
	dispatch.quest_since = int(file.get_value("dispatch", "quest_since", 0))
	dispatch.checked_at = int(file.get_value("dispatch", "checked_at", now))
	return dispatch
