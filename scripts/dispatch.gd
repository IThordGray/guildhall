class_name Dispatch
extends RefCounted

## Every quest the board can offer: see Board. The save refers to a quest by its id. A
## quest's challenges say why it is hard (see Challenges); its difficulty is never shown. Durations,
## gold and difficulties are stand-ins, tuned so the four starters have good odds on every rank F
## quest, fair odds together on rank E and little hope on rank D.
const QUESTS: Dictionary[String, Dictionary] = {
	"rats": {"name": "Rats in the cellar", "rank": "F", "seconds": 60, "gold": 50, "difficulty": 3, "challenges": ["Brute force"]},
	"well": {"name": "Lift the hex on the town well", "rank": "F", "seconds": 90, "gold": 70, "difficulty": 4, "challenges": ["Curse"]},
	"letters": {"name": "Carry letters to the abbey", "rank": "F", "seconds": 120, "gold": 100, "difficulty": 4, "challenges": ["Navigation", "Protect"]},
	"spiders": {"name": "Spiders in the gatehouse", "rank": "F", "seconds": 120, "gold": 100, "difficulty": 5, "challenges": ["Brute force", "Attrition"]},
	"cartographer": {"name": "Escort the cartographer to the first gate", "rank": "F", "seconds": 150, "gold": 120, "difficulty": 4, "challenges": ["Protect", "Traps"]},
	"mouth": {"name": "Chart the labyrinth's mouth", "rank": "F", "seconds": 150, "gold": 120, "difficulty": 5, "challenges": ["Traps", "Navigation"]},
	"moonherbs": {"name": "Gather moonherbs", "rank": "F", "seconds": 180, "gold": 150, "difficulty": 4, "challenges": ["Navigation", "Attrition"]},
	"wolves": {"name": "Wolves at the mill", "rank": "E", "seconds": 300, "gold": 250, "difficulty": 9, "challenges": ["Brute force", "Attrition"]},
	"sealed_door": {"name": "Break the curse on the sealed door", "rank": "E", "seconds": 360, "gold": 300, "difficulty": 10, "challenges": ["Curse", "Navigation"]},
	"lurker": {"name": "Hunt the cave lurker", "rank": "E", "seconds": 420, "gold": 350, "difficulty": 9, "challenges": ["Brute force", "Curse"]},
	"crypt": {"name": "Clear the old crypt", "rank": "E", "seconds": 480, "gold": 400, "difficulty": 11, "challenges": ["Curse", "Traps", "Attrition"]},
	"pilgrims": {"name": "Guard pilgrims through the low halls", "rank": "E", "seconds": 540, "gold": 450, "difficulty": 10, "challenges": ["Protect", "Attrition"]},
	"goblins": {"name": "Goblin camp", "rank": "E", "seconds": 600, "gold": 500, "difficulty": 11, "challenges": ["Brute force", "Traps", "Navigation"]},
	"maze": {"name": "Map the shifting maze", "rank": "D", "seconds": 900, "gold": 700, "difficulty": 14, "challenges": ["Navigation", "Traps"]},
	"chapel": {"name": "Unbind the drowned chapel", "rank": "D", "seconds": 1_080, "gold": 800, "difficulty": 15, "challenges": ["Curse", "Attrition"]},
	"minotaur": {"name": "Slay the minotaur of the third ring", "rank": "D", "seconds": 1_200, "gold": 900, "difficulty": 15, "challenges": ["Brute force", "Attrition"]},
	"envoy": {"name": "Escort the envoy to the deep market", "rank": "D", "seconds": 1_500, "gold": 1_000, "difficulty": 14, "challenges": ["Protect", "Traps", "Navigation"]},
	"vault": {"name": "Raid the bone king's vault", "rank": "D", "seconds": 1_800, "gold": 1_200, "difficulty": 16, "challenges": ["Curse", "Traps", "Protect"]},
}
const MAX_PARTY_SIZE: int = 4
## How long an injury lasts, counted from the moment the party returns.
const INJURY_SECONDS: int = 300
## The same with an Infirmary finished by the moment of return; more Infirmaries don't shorten it.
const INFIRMARY_INJURY_SECONDS: int = 150
## Seconds to heal one point of health; from the moment the first Infirmary is finished, half that.
const HEAL_SECONDS: int = 20
## An adventurer in training gains this much XP per whole minute since their stint started, at most
## TRAINING_MAX_XP a stint; the cap is the reason to come back (stand-ins).
const TRAINING_XP_PER_MINUTE: int = 1
const TRAINING_MAX_XP: int = 60
## Once an adventurer has trained this many seconds in all, the Training room hints at their growth.
const TRAINING_HINT_SECONDS: int = 600
## Why an adventurer can't start training while every Training room's one place is taken.
const NO_TRAINING_PLACE: String = "No free training place — convert a Training room"

## Parties out, in the order they left. Each is {"quest": quest id, "since": unix seconds it left,
## "party": adventurer ids, "seed": the seed that fixes how it ends, "chance": its whole-percent
## chance of success when it left, "health" and "max_health": {adventurer id: points} each member
## left with}. A party counts as out until the checkpoint after its return brings it home.
var outings: Array[Dictionary] = []
## Unix seconds each injured adventurer recovers at. A member who comes home under a quarter of
## their maximum health is injured.
var injured_until: Dictionary[String, int] = {}
## How many seconds each adventurer's latest injury lasts in all, fixed when it was decided.
var injury_lengths: Dictionary[String, int] = {}
## Returns the player has not read yet, in the order they came back. Each is {"quest": quest id,
## "returned_at": unix seconds it came back, "success": bool, "party": adventurer ids,
## "damage": {adventurer id: damage taken}, "injured": {adventurer id: seconds the injury lasts},
## "gold": gold it brought, "xp": XP each member gained, "revealed": the quest's challenges it
## made known, "loot": item ids it put in the stash, "lost": item ids it brought to a full stash}.
## Only a report: its outcome was applied when the party came home.
var debriefs: Array[Dictionary] = []
## Who is in the guild, and each one's stats, level, XP and gear: their power decides quests, and
## returns grow them.
var adventurers: Adventurers = Adventurers.new()
## The health each adventurer below their maximum came home with: {"health": points, "at": unix
## seconds they came home}. Their health at home is computed from it; anyone missing is at full
## health.
var wounds: Dictionary[String, Dictionary] = {}
## Quests whose unknown challenges a returning party has made known, for good.
var revealed: PackedStringArray = PackedStringArray()
## Unix seconds each adventurer in training started their stint at. Their XP from it is computed
## from this alone and banked when they stop.
var training: Dictionary[String, int] = {}
## Seconds each adventurer has trained in all over stints already stopped.
var trained_seconds: Dictionary[String, int] = {}
## Latest unix seconds seen. Time is read as never earlier than this, so a clock set back neither
## adds time to a quest or an injury nor brings back a party that has returned.
var checked_at: int
## The unix seconds the first Infirmary is finished at, as the last checkpoint was told; -1 for none.
var _infirmary_from: int = -1


func _init(at: int) -> void:
	checked_at = at


## The whole-percent chance that `party`, as they are now, succeeds on `quest_id`, counting every
## challenge, known to the player or not.
func success_chance(quest_id: String, party: PackedStringArray) -> int:
	var uncovered := 0
	for challenge: String in QUESTS[quest_id]["challenges"]:
		if Challenges.covered_by(challenge, party, adventurers.roster).is_empty():
			uncovered += 1
	return Outcome.chance_percent(party_power(party), int(QUESTS[quest_id]["difficulty"]), uncovered)


## The chance the player is shown for `party` on `quest_id`, as [low, high] in whole percent: see
## Outcome.chance_range. The true chance always lies inside.
func chance_range(quest_id: String, party: PackedStringArray) -> Vector2i:
	var unknown := unknown_challenges(quest_id)
	var uncovered := 0
	for challenge: String in QUESTS[quest_id]["challenges"]:
		if challenge not in unknown and Challenges.covered_by(challenge, party, adventurers.roster).is_empty():
			uncovered += 1
	return Outcome.chance_range(party_power(party), int(QUESTS[quest_id]["difficulty"]), uncovered, unknown.size())


## The challenges of `quest_id` the player doesn't know yet. A quest's last challenge starts
## unknown, unless it is its only one; a party back from the quest makes them known for good.
func unknown_challenges(quest_id: String) -> PackedStringArray:
	var challenges: Array = QUESTS[quest_id]["challenges"]
	if quest_id in revealed or challenges.size() < 2:
		return PackedStringArray()
	return PackedStringArray([challenges[-1]])


## The power `party` brings to a quest: its members' power, except a Healer's own.
func party_power(party: PackedStringArray) -> int:
	var total := 0
	for adventurer: String in party:
		if not is_healer(adventurers.roster[adventurer]):
			total += adventurers.power(adventurer)
	return total


## True when the adventurer who is `who`, as Adventurers.roster has them, is a Healer: their power
## doesn't count, and a party with one takes half damage.
static func is_healer(who: Dictionary) -> bool:
	return who["class"] == "Healer"


## The gold `quest_id` brings when it fails: a quarter of its reward, rounded down.
static func failure_gold(quest_id: String) -> int:
	return floori(int(QUESTS[quest_id]["gold"]) / 4.0)


## Seconds until `outing` returns; 0 when it has returned.
func seconds_left(outing: Dictionary, now: int) -> int:
	return maxi(0, back_at(outing) - maxi(now, checked_at))


## Seconds until `adventurer` recovers from an injury; 0 when not injured.
func injury_left(adventurer: String, now: int) -> int:
	return maxi(0, int(injured_until.get(adventurer, 0)) - maxi(now, checked_at))


## How many seconds `adventurer`'s latest injury lasts in all; the long injury for one saved
## before lengths were kept.
func injury_seconds(adventurer: String) -> int:
	return injury_lengths.get(adventurer, INJURY_SECONDS)


## `adventurer`'s health at `now`. Out on a quest, what they left with: nobody heals while out. At
## home, what their last return left them with, plus a point per HEAL_SECONDS since (twice as fast
## from the moment the Infirmary is finished), up to their maximum.
func health(adventurer: String, now: int) -> int:
	var outing := _outing_of(adventurer)
	if outing.has("health"):
		return outing["health"][adventurer]
	return _health_at(adventurer, maxi(now, checked_at))


## Seconds from `now` until `adventurer` is back to full health; 0 when full, or out on a quest,
## where nobody heals.
func seconds_to_full(adventurer: String, now: int) -> int:
	if not wounds.has(adventurer) or not _outing_of(adventurer).is_empty():
		return 0
	var at := maxi(now, checked_at)
	var wound := wounds[adventurer]
	var need := HEAL_SECONDS * (adventurers.max_health(adventurer) - int(wound["health"])) - _heal_units(int(wound["at"]), at)
	if need <= 0:
		return 0
	if _infirmary_from < 0:
		return need
	var slow := maxi(0, _infirmary_from - at)
	if need <= slow:
		return need
	return slow + ceili((need - slow) / 2.0)


## True when `points` of health are under a quarter of `most`: coming home like that injures.
static func under_a_quarter(points: int, most: int) -> bool:
	return points * 4 < most


func _health_at(adventurer: String, at: int) -> int:
	var most := adventurers.max_health(adventurer)
	if not wounds.has(adventurer):
		return most
	var wound := wounds[adventurer]
	return mini(most, int(wound["health"]) + floori(_heal_units(int(wound["at"]), at) / float(HEAL_SECONDS)))


# The healing from `from` to `to`, in seconds at the slow rate: each second from the moment the
# Infirmary is finished counts twice.
func _heal_units(from: int, to: int) -> int:
	if to <= from:
		return 0
	var fast_from := to if _infirmary_from < 0 else clampi(_infirmary_from, from, to)
	return (fast_from - from) + 2 * (to - fast_from)


## The quest `adventurer` is out on, or "" when home.
func quest_of(adventurer: String) -> String:
	return _outing_of(adventurer).get("quest", "")


# The outing `adventurer` is on, or {} when home.
func _outing_of(adventurer: String) -> Dictionary:
	for outing: Dictionary in outings:
		if adventurer in outing["party"]:
			return outing
	return {}


## True when `adventurer` may change gear: not while out, so a party's chance and health stay
## as they left.
func can_change_gear(adventurer: String) -> bool:
	return quest_of(adventurer).is_empty()


## Puts the stash item at `index` on `adventurer`, the item it replaces into the stash; false, with
## nothing changed, while they are out.
func wear(adventurer: String, index: int) -> bool:
	if not can_change_gear(adventurer):
		return false
	adventurers.gear.wear(adventurer, index)
	return true


## True when `adventurer` can join a party at `now`: home, not injured and not training.
func can_go(adventurer: String, now: int) -> bool:
	return quest_of(adventurer).is_empty() and injury_left(adventurer, now) == 0 and not training.has(adventurer)


## What `adventurer` is doing at `now`, in words for the player.
func status(adventurer: String, now: int) -> String:
	var quest := quest_of(adventurer)
	if not quest.is_empty():
		return "On quest: " + QUESTS[quest]["name"]
	var injured := injury_left(adventurer, now)
	if injured > 0:
		return "Injured · " + Duration.label(injured)
	if training.has(adventurer):
		return "Training"
	return "Resting"


## Why `adventurer` can't start training at `now` with `places` finished Training rooms, one place
## each, in words for the player; "" when they can.
func training_refusal(adventurer: String, places: int, now: int) -> String:
	if training.has(adventurer):
		return "Already training"
	if not quest_of(adventurer).is_empty():
		return "Out on a quest"
	if injury_left(adventurer, now) > 0:
		return "Injured"
	if training.size() >= places:
		return NO_TRAINING_PLACE
	return ""


## Starts `adventurer` training at `now`; false, with nothing changed, when `training_refusal`
## gives a reason.
func train(adventurer: String, places: int, now: int) -> bool:
	if not training_refusal(adventurer, places, now).is_empty():
		return false
	training[adventurer] = maxi(now, checked_at)
	return true


## The XP `adventurer`'s current stint has earned by `now`: TRAINING_XP_PER_MINUTE a whole minute,
## at most TRAINING_MAX_XP; 0 when not training.
func training_xp(adventurer: String, now: int) -> int:
	if not training.has(adventurer):
		return 0
	var minutes := floori((maxi(now, checked_at) - training[adventurer]) / 60.0)
	return mini(TRAINING_MAX_XP, minutes * TRAINING_XP_PER_MINUTE)


## Ends `adventurer`'s stint at `now` and banks its XP into theirs; the XP banked. Not training
## gives 0, with nothing changed.
func stop_training(adventurer: String, now: int) -> int:
	if not training.has(adventurer):
		return 0
	var xp := training_xp(adventurer, now)
	trained_seconds[adventurer] = _seconds_trained(adventurer, now)
	training.erase(adventurer)
	adventurers.gain_xp(adventurer, xp)
	return xp


## The name of the stat `adventurer` grows fastest in, ties going to the first in
## Adventurers.STATS, once they have trained TRAINING_HINT_SECONDS in all by `now`; "" before.
## Growth numbers themselves are never shown.
func training_hint(adventurer: String, now: int) -> String:
	if _seconds_trained(adventurer, now) < TRAINING_HINT_SECONDS:
		return ""
	var growth: Dictionary = adventurers.growth[adventurer]
	var fastest := ""
	for stat: String in Adventurers.STATS:
		if fastest.is_empty() or float(growth[stat]) > float(growth[fastest]):
			fastest = stat
	return Adventurers.STATS[fastest]


# Seconds `adventurer` has trained in all by `now`, the current stint included.
func _seconds_trained(adventurer: String, now: int) -> int:
	var seconds: int = trained_seconds.get(adventurer, 0)
	if training.has(adventurer):
		seconds += maxi(now, checked_at) - training[adventurer]
	return seconds


## Why `party` can't be sent on `quest_id` at `now`, in words for the player; "" when it can.
## However many parties are out, anyone home, well and of a rank the quest allows can go.
func party_refusal(quest_id: String, party: PackedStringArray, now: int) -> String:
	if party.is_empty():
		return "Pick at least one adventurer"
	if party.size() > MAX_PARTY_SIZE:
		return "At most %d in a party" % MAX_PARTY_SIZE
	for adventurer: String in party:
		var who: Dictionary = adventurers.roster[adventurer]
		if not can_go(adventurer, now):
			return "%s can't go" % who["name"]
		if not Challenges.can_join(who["rank"], QUESTS[quest_id]["rank"]):
			return "%s's rank is too low" % who["name"]
	return ""


## Sends `party` on `quest_id` at `now`, its outcome fixed by `roll_seed`; false, with nothing
## started, when `party_refusal` gives a reason. Which quests can be sent is Board's rule.
## `infirmary_from` is as for `checkpoint`.
func send(quest_id: String, party: PackedStringArray, roll_seed: int, gold: Gold, now: int, infirmary_from: int = -1) -> bool:
	checkpoint(now, gold, infirmary_from)
	if not party_refusal(quest_id, party, now).is_empty():
		return false
	# Health is fixed on leaving, like the chance, so a level-up while out changes nothing about how
	# the quest ends.
	var health_left_with := {}
	var max_left_with := {}
	for adventurer: String in party:
		health_left_with[adventurer] = health(adventurer, checked_at)
		max_left_with[adventurer] = adventurers.max_health(adventurer)
	outings.append({"quest": quest_id, "since": checked_at, "party": party.duplicate(), "seed": roll_seed, "chance": success_chance(quest_id, party), "health": health_left_with, "max_health": max_left_with})
	return true


## True when a party returned after the last checkpoint: the "while you were away" news when the
## checkpoint was taken on leaving. Its outcome is applied at the next checkpoint.
func returned_since_checkpoint(now: int) -> bool:
	for outing: Dictionary in outings:
		if seconds_left(outing, now) == 0:
			return true
	return false


## Brings every returned party home, once, in the order they returned: pays its reward into
## `gold`, gives each member XP and damage, injures those it leaves under a quarter of their
## health, stows any loot, and adds its debrief. `infirmary_from` is the unix seconds the first Infirmary is
## finished at, -1 for none: from then on healing is faster, and an injury from a return at or
## after it is shorter. Records the time seen.
func checkpoint(now: int, gold: Gold, infirmary_from: int = -1) -> void:
	checked_at = maxi(checked_at, now)
	_infirmary_from = infirmary_from
	var returned: Array[Dictionary] = []
	for outing: Dictionary in outings:
		if seconds_left(outing, checked_at) == 0:
			returned.append(outing)
	returned.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return back_at(a) < back_at(b))
	for outing: Dictionary in returned:
		outings.erase(outing)
		_bring_home(outing, gold)


func _bring_home(outing: Dictionary, gold: Gold) -> void:
	var quest: Dictionary = QUESTS[outing["quest"]]
	var party: PackedStringArray = outing["party"]
	var returns_at := back_at(outing)
	var reward: int = quest["gold"]
	var success := true
	var damage: Dictionary = {}
	var injured: Dictionary = {}
	# A party sent before adventurers existed has no members: it comes home as it was sent then,
	# paid in full.
	if not party.is_empty():
		# The chance is the one it left with, so a level-up while out never changes how it ends. One
		# sent before chances were kept rolls with the power it has now, which is the power it had
		# then: nobody could level up before.
		var chance: int = outing.get("chance", success_chance(outing["quest"], party))
		var outcome := Outcome.roll(outing["seed"], chance, Outcome.MOST_DAMAGE[quest["rank"]], party, adventurers.roster)
		success = outcome.success
		if not success:
			reward = failure_gold(outing["quest"])
		damage = outcome.damage
		var healed_in := INFIRMARY_INJURY_SECONDS if _infirmary_from >= 0 and _infirmary_from <= returns_at else INJURY_SECONDS
		for adventurer: String in party:
			# One sent before health was kept left with what they have now.
			var left_with: int = outing.get("health", {}).get(adventurer, _health_at(adventurer, returns_at))
			var most: int = outing.get("max_health", {}).get(adventurer, adventurers.max_health(adventurer))
			# Nobody dies yet: damage leaves at least 1 health.
			var back_with := maxi(1, left_with - int(damage[adventurer]))
			if back_with < adventurers.max_health(adventurer):
				wounds[adventurer] = {"health": back_with, "at": returns_at}
			else:
				wounds.erase(adventurer)
			if under_a_quarter(back_with, most):
				injured_until[adventurer] = returns_at + healed_in
				injury_lengths[adventurer] = healed_in
				injured[adventurer] = healed_in
	var revealing := unknown_challenges(outing["quest"])
	if not revealing.is_empty():
		revealed.append(outing["quest"])
	gold.amount += reward
	var xp := Adventurers.quest_xp(quest["seconds"], success)
	for adventurer: String in party:
		adventurers.gain_xp(adventurer, xp)
	# Loot comes whatever the outcome, from the seed the party left with.
	var loot := PackedStringArray()
	var lost := PackedStringArray()
	var item := Gear.loot(outing["seed"], quest["rank"])
	if not item.is_empty():
		if adventurers.gear.stow(item):
			loot.append(item)
		else:
			lost.append(item)
	debriefs.append({"quest": outing["quest"], "returned_at": returns_at, "success": success, "party": party, "damage": damage, "injured": injured, "gold": reward, "xp": xp, "revealed": revealing, "loot": loot, "lost": lost})


## Files the debrief at `index` away once the player has read it; nothing else changes.
func read_debrief(index: int) -> void:
	debriefs.remove_at(index)


## How long ago `debrief` came back at `now`, in words for the player: whole minutes, or "just
## now" under one.
func back_label(debrief: Dictionary, now: int) -> String:
	var minutes := floori((maxi(now, checked_at) - int(debrief["returned_at"])) / 60.0)
	return "Back just now" if minutes == 0 else "Back %d min ago" % minutes


## Unix seconds `outing`'s party is back, fixed when it leaves.
func back_at(outing: Dictionary) -> int:
	return int(outing["since"]) + int(QUESTS[outing["quest"]]["seconds"])


## Puts the dispatch into `file`, which other state shares, so one save holds the whole game.
func write(file: ConfigFile) -> void:
	file.set_value("dispatch", "outings", outings)
	file.set_value("dispatch", "injured_until", injured_until)
	file.set_value("dispatch", "injury_lengths", injury_lengths)
	file.set_value("dispatch", "debriefs", debriefs)
	file.set_value("dispatch", "wounds", wounds)
	file.set_value("dispatch", "revealed", revealed)
	file.set_value("dispatch", "training", training)
	file.set_value("dispatch", "trained_seconds", trained_seconds)
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
	# A save from before health has nobody hurt: everyone loads at full health.
	dispatch.wounds.assign(file.get_value("dispatch", "wounds", {}))
	# A save from before challenges were known knows what every new guild knows.
	dispatch.revealed = file.get_value("dispatch", "revealed", PackedStringArray())
	# A save from before training has nobody training and nobody trained.
	dispatch.training.assign(file.get_value("dispatch", "training", {}))
	dispatch.trained_seconds.assign(file.get_value("dispatch", "trained_seconds", {}))
	dispatch.checked_at = int(file.get_value("dispatch", "checked_at", now))
	return dispatch
