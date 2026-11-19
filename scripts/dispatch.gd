class_name Dispatch
extends RefCounted

## Every quest a day's board can offer: see Board. The save refers to a quest by its id.
const QUESTS: Dictionary[String, Dictionary] = {
	"rats": {"name": "Rats in the cellar", "seconds": 60, "gold": 50, "difficulty": 3},
	"moonherbs": {"name": "Gather moonherbs", "seconds": 180, "gold": 150, "difficulty": 7},
	"goblins": {"name": "Goblin camp", "seconds": 600, "gold": 500, "difficulty": 12},
	"letters": {"name": "Carry letters to the abbey", "seconds": 120, "gold": 100, "difficulty": 5},
	"wolves": {"name": "Wolves at the mill", "seconds": 300, "gold": 250, "difficulty": 9},
	"crypt": {"name": "Clear the old crypt", "seconds": 480, "gold": 400, "difficulty": 11},
}
## The guild's adventurers, in roster order, as they always are. The save refers to one by its
## id. How they grow is in `adventurers`.
const ADVENTURERS: Dictionary[String, Dictionary] = {
	"bram": {"name": "Bram", "class": "Swordsman", "rank": "F"},
	"ilse": {"name": "Ilse", "class": "Mage", "rank": "F"},
	"tobin": {"name": "Tobin", "class": "Scout", "rank": "F"},
	"maren": {"name": "Maren", "class": "Healer", "rank": "F"},
}
const MAX_PARTY_SIZE: int = 4
## How long a failed quest injures one of its party, counted from the moment the party returns.
const INJURY_SECONDS: int = 300
## The same with an Infirmary finished by the moment of return; more Infirmaries don't shorten it.
const INFIRMARY_INJURY_SECONDS: int = 150

## Parties out, in the order they left. Each is {"quest": quest id, "since": unix seconds it left,
## "party": adventurer ids, "seed": the seed that fixes how it ends, "chance": its whole-percent
## chance of success when it left}. A party counts as out until the checkpoint after its return
## brings it home.
var outings: Array[Dictionary] = []
## Unix seconds each adventurer hurt on a failed quest recovers at.
var injured_until: Dictionary[String, int] = {}
## How many seconds each adventurer's latest injury lasts in all, fixed when it was decided.
var injury_lengths: Dictionary[String, int] = {}
## Returns the player has not read yet, in the order they came back. Each is {"quest": quest id,
## "returned_at": unix seconds it came back, "success": bool, "party": adventurer ids,
## "injured": {adventurer id: seconds the injury lasts}, "gold": gold it brought, "xp": XP each
## member gained}. Only a report: its outcome was applied when the party came home.
var debriefs: Array[Dictionary] = []
## Each adventurer's stats, level and XP: their power decides quests, and returns grow them.
var adventurers: Adventurers = Adventurers.new()
## Latest unix seconds seen. Time is read as never earlier than this, so a clock set back neither
## adds time to a quest or an injury nor brings back a party that has returned.
var checked_at: int


func _init(at: int) -> void:
	checked_at = at


## The whole-percent chance that `party`, as they are now, succeeds on `quest_id`.
func success_chance(quest_id: String, party: PackedStringArray) -> int:
	return Outcome.chance_percent(adventurers.party_power(party), int(QUESTS[quest_id]["difficulty"]))


## Seconds until `outing` returns; 0 when it has returned.
func seconds_left(outing: Dictionary, now: int) -> int:
	return maxi(0, _returns_at(outing) - maxi(now, checked_at))


## Seconds until `adventurer` recovers from an injury; 0 when not injured.
func injury_left(adventurer: String, now: int) -> int:
	return maxi(0, int(injured_until.get(adventurer, 0)) - maxi(now, checked_at))


## How many seconds `adventurer`'s latest injury lasts in all; the long injury for one saved
## before lengths were kept.
func injury_seconds(adventurer: String) -> int:
	return injury_lengths.get(adventurer, INJURY_SECONDS)


## The quest `adventurer` is out on, or "" when home.
func quest_of(adventurer: String) -> String:
	for outing: Dictionary in outings:
		if adventurer in outing["party"]:
			return outing["quest"]
	return ""


## True when `adventurer` can join a party at `now`: home and not injured.
func can_go(adventurer: String, now: int) -> bool:
	return quest_of(adventurer).is_empty() and injury_left(adventurer, now) == 0


## What `adventurer` is doing at `now`, in words for the player.
func status(adventurer: String, now: int) -> String:
	var quest := quest_of(adventurer)
	if not quest.is_empty():
		return "On quest: " + QUESTS[quest]["name"]
	var injured := injury_left(adventurer, now)
	if injured > 0:
		return "Injured · " + Duration.label(injured)
	return "Resting"


## Why `party` can't be sent at `now`, in words for the player; "" when it can. However many
## parties are out, anyone home and well can go.
func party_refusal(party: PackedStringArray, now: int) -> String:
	if party.is_empty():
		return "Pick at least one adventurer"
	if party.size() > MAX_PARTY_SIZE:
		return "At most %d in a party" % MAX_PARTY_SIZE
	for adventurer: String in party:
		if not can_go(adventurer, now):
			return "%s can't go" % ADVENTURERS[adventurer]["name"]
	return ""


## Sends `party` on `quest_id` at `now`, its outcome fixed by `roll_seed`; false, with nothing
## started, when `party_refusal` gives a reason. Which quests can be sent is Board's rule.
## `infirmary_from` is as for `checkpoint`.
func send(quest_id: String, party: PackedStringArray, roll_seed: int, gold: Gold, now: int, infirmary_from: int = -1) -> bool:
	checkpoint(now, gold, infirmary_from)
	if not party_refusal(party, now).is_empty():
		return false
	outings.append({"quest": quest_id, "since": checked_at, "party": party.duplicate(), "seed": roll_seed, "chance": success_chance(quest_id, party)})
	return true


## True when a party returned after the last checkpoint: the "while you were away" news when the
## checkpoint was taken on leaving. Its outcome is applied at the next checkpoint.
func returned_since_checkpoint(now: int) -> bool:
	for outing: Dictionary in outings:
		if seconds_left(outing, now) == 0:
			return true
	return false


## Brings every returned party home, once, in the order they returned: pays its reward into
## `gold`, gives each member XP, injures on failure and adds its debrief. `infirmary_from` is the unix seconds the first
## Infirmary is finished at, -1 for none: an injury from a return at or after it is shorter.
## Records the time seen.
func checkpoint(now: int, gold: Gold, infirmary_from: int = -1) -> void:
	checked_at = maxi(checked_at, now)
	var returned: Array[Dictionary] = []
	for outing: Dictionary in outings:
		if seconds_left(outing, checked_at) == 0:
			returned.append(outing)
	returned.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _returns_at(a) < _returns_at(b))
	for outing: Dictionary in returned:
		outings.erase(outing)
		_bring_home(outing, gold, infirmary_from)


func _bring_home(outing: Dictionary, gold: Gold, infirmary_from: int) -> void:
	var quest: Dictionary = QUESTS[outing["quest"]]
	var party: PackedStringArray = outing["party"]
	var returns_at := _returns_at(outing)
	var reward: int = quest["gold"]
	var success := true
	var injured: Dictionary = {}
	# A party sent before adventurers existed has no members: it comes home as it was sent then,
	# paid in full.
	if not party.is_empty():
		# The chance is the one it left with, so a level-up while out never changes how it ends. One
		# sent before chances were kept rolls with the power it has now, which is the power it had
		# then: nobody could level up before.
		var chance: int = outing.get("chance", success_chance(outing["quest"], party))
		var outcome := Outcome.roll(outing["seed"], chance, party)
		if not outcome.success:
			reward = floori(reward / 4.0)
			success = false
			var healed_in := INFIRMARY_INJURY_SECONDS if infirmary_from >= 0 and infirmary_from <= returns_at else INJURY_SECONDS
			injured_until[outcome.injured] = returns_at + healed_in
			injury_lengths[outcome.injured] = healed_in
			injured[outcome.injured] = healed_in
	gold.amount += reward
	var xp := Adventurers.quest_xp(quest["seconds"], success)
	for adventurer: String in party:
		adventurers.gain_xp(adventurer, xp)
	debriefs.append({"quest": outing["quest"], "returned_at": returns_at, "success": success, "party": party, "injured": injured, "gold": reward, "xp": xp})


## Files the debrief at `index` away once the player has read it; nothing else changes.
func read_debrief(index: int) -> void:
	debriefs.remove_at(index)


## How long ago `debrief` came back at `now`, in words for the player: whole minutes, or "just
## now" under one.
func back_label(debrief: Dictionary, now: int) -> String:
	var minutes := floori((maxi(now, checked_at) - int(debrief["returned_at"])) / 60.0)
	return "Back just now" if minutes == 0 else "Back %d min ago" % minutes


func _returns_at(outing: Dictionary) -> int:
	return int(outing["since"]) + int(QUESTS[outing["quest"]]["seconds"])


## Puts the dispatch into `file`, which other state shares, so one save holds the whole game.
func write(file: ConfigFile) -> void:
	file.set_value("dispatch", "outings", outings)
	file.set_value("dispatch", "injured_until", injured_until)
	file.set_value("dispatch", "injury_lengths", injury_lengths)
	file.set_value("dispatch", "debriefs", debriefs)
	file.set_value("dispatch", "checked_at", checked_at)
	adventurers.write(file)


## The dispatch saved at `path`, or everyone home and well at `now` when the save has none.
static func load_or_start(path: String, now: int) -> Dispatch:
	var dispatch := Dispatch.new(now)
	dispatch.adventurers = Adventurers.load_or_start(path)
	var file := ConfigFile.new()
	if file.load(path) != OK or not file.has_section("dispatch"):
		return dispatch
	if file.has_section_key("dispatch", "outings"):
		dispatch.outings.assign(file.get_value("dispatch", "outings"))
	else:
		# Saves from before adventurers hold at most one party out, under "quest", with no members.
		var quest: String = file.get_value("dispatch", "quest", "")
		if not quest.is_empty():
			dispatch.outings.append({"quest": quest, "since": int(file.get_value("dispatch", "quest_since", 0)), "party": PackedStringArray(), "seed": 0})
	# A party on a quest the board no longer has could never return, so it is taken as home.
	for outing: Dictionary in dispatch.outings.duplicate():
		if outing["quest"] not in QUESTS:
			dispatch.outings.erase(outing)
	dispatch.injured_until.assign(file.get_value("dispatch", "injured_until", {}))
	dispatch.injury_lengths.assign(file.get_value("dispatch", "injury_lengths", {}))
	dispatch.debriefs.assign(file.get_value("dispatch", "debriefs", []))
	dispatch.checked_at = int(file.get_value("dispatch", "checked_at", now))
	return dispatch
