class_name Dispatch
extends RefCounted

## Every quest the board can offer: see Board. The save refers to a quest by its id. A
## quest's challenges say why it is hard (see Challenges); its difficulty, what each challenge needs
## (Challenges.requirement), is never shown. Durations and difficulties are stand-ins. Rank F
## difficulties are tuned so a new game's Bram and Tobin together have at least 80% on every rank F
## quest and each alone 45–75%; the four starters have fair odds together on rank E and little
## hope on rank D. Gold is a stand-in too, kept small next to what the guild can spend so a quest's
## reward matters. "xp" is the XP the whole party shares on a success. A quest with "story" true is a
## story quest: the board never offers it; it is open once Goals unlocks its id, until a party comes
## home from it successfully (`story_done`), and every challenge of it is known. "reputation", where
## a quest has it, is what a success earns in place of REPUTATION for its rank. A quest with a "floor"
## number is a floor of the labyrinth (Labyrinth): the board never offers it, but it can be gone on
## again and again; floor 1 is open once Goals unlocks Labyrinth.UNLOCK, and each floor after once
## the one above is Labyrinth.NEXT_FLOOR_AT explored (`open_floors`).
const QUESTS: Dictionary[String, Dictionary] = {
	"rats": {"name": "Rats in the cellar", "rank": "F", "seconds": 2, "gold": 3, "xp": 4, "difficulty": 11, "challenges": ["Brute force"]},
	"well": {"name": "Lift the hex on the town well", "rank": "F", "seconds": 3, "gold": 5, "xp": 5, "difficulty": 0, "challenges": ["Curse"]},
	"letters": {"name": "Carry letters to the abbey", "rank": "F", "seconds": 4, "gold": 7, "xp": 6, "difficulty": 1, "challenges": ["Navigation", "Negotiation"]},
	"spiders": {"name": "Spiders in the gatehouse", "rank": "F", "seconds": 4, "gold": 7, "xp": 6, "difficulty": 9, "challenges": ["Brute force", "Attrition"]},
	"cartographer": {"name": "Escort the cartographer to the first gate", "rank": "F", "seconds": 5, "gold": 8, "xp": 7, "difficulty": 6, "challenges": ["Protect", "Traps"]},
	"mouth": {"name": "Chart the labyrinth's mouth", "rank": "F", "seconds": 5, "gold": 8, "xp": 7, "difficulty": 7, "challenges": ["Traps", "Navigation"]},
	"moonherbs": {"name": "Gather moonherbs", "rank": "F", "seconds": 6, "gold": 10, "xp": 8, "difficulty": 3, "challenges": ["Navigation", "Attrition"]},
	"wolves": {"name": "Wolves at the mill", "rank": "E", "seconds": 10, "gold": 22, "xp": 15, "difficulty": 40, "challenges": ["Brute force", "Attrition"]},
	"sealed_door": {"name": "Break the curse on the sealed door", "rank": "E", "seconds": 12, "gold": 25, "xp": 18, "difficulty": 54, "challenges": ["Curse", "Navigation"]},
	"lurker": {"name": "Hunt the cave lurker", "rank": "E", "seconds": 14, "gold": 30, "xp": 21, "difficulty": 44, "challenges": ["Brute force", "Curse"]},
	"crypt": {"name": "Clear the old crypt", "rank": "E", "seconds": 16, "gold": 33, "xp": 24, "difficulty": 55, "challenges": ["Curse", "Traps", "Attrition"]},
	"pilgrims": {"name": "Guard pilgrims through the low halls", "rank": "E", "seconds": 18, "gold": 38, "xp": 27, "difficulty": 56, "challenges": ["Protect", "Attrition"], "labyrinth": true},
	"goblins": {"name": "Goblin camp", "rank": "E", "seconds": 20, "gold": 42, "xp": 30, "difficulty": 53, "challenges": ["Brute force", "Traps", "Navigation"]},
	"maze": {"name": "Map the shifting maze", "rank": "D", "seconds": 30, "gold": 87, "xp": 50, "difficulty": 72, "challenges": ["Navigation", "Traps"], "labyrinth": true},
	"chapel": {"name": "Unbind the drowned chapel", "rank": "D", "seconds": 36, "gold": 100, "xp": 60, "difficulty": 76, "challenges": ["Curse", "Attrition"]},
	"minotaur": {"name": "Slay the minotaur of the third ring", "rank": "D", "seconds": 40, "gold": 113, "xp": 67, "difficulty": 70, "challenges": ["Brute force", "Attrition"], "labyrinth": true},
	"envoy": {"name": "Escort the envoy to the deep market", "rank": "D", "seconds": 50, "gold": 125, "xp": 83, "difficulty": 91, "challenges": ["Protect", "Negotiation", "Navigation"]},
	"vault": {"name": "Raid the bone king's vault", "rank": "D", "seconds": 60, "gold": 150, "xp": 100, "difficulty": 83, "challenges": ["Curse", "Traps", "Protect"]},
	# A new game's Bram and Tobin, at level 1 in their starting gear, have about 60%.
	"sealed_gate": {"name": "The sealed gate", "rank": "F", "seconds": 10, "gold": 30, "xp": 15, "difficulty": 17, "challenges": ["Curse", "Traps"], "story": true, "reputation": 3},
	"floor_1": {"name": "The Galleries", "rank": "E", "seconds": 60, "gold": 45, "xp": 32, "difficulty": 48, "challenges": ["Traps", "Navigation", "Attrition"], "floor": 1},
	"floor_2": {"name": "The Drowned Stair", "rank": "E", "seconds": 90, "gold": 60, "xp": 45, "difficulty": 56, "challenges": ["Curse", "Navigation", "Attrition"], "floor": 2},
	"floor_3": {"name": "The Third Ring", "rank": "D", "seconds": 120, "gold": 130, "xp": 85, "difficulty": 74, "challenges": ["Brute force", "Traps", "Curse"], "floor": 3},
}
const MAX_PARTY_SIZE: int = 4
## How long an injury lasts, counted from the moment the party returns.
const INJURY_SECONDS: int = 10
## The same with an Infirmary finished by the moment of return; more Infirmaries don't shorten it.
const INFIRMARY_INJURY_SECONDS: int = 5
## Health heals HEAL_POINTS points every HEAL_SECONDS seconds, counted in whole points from the
## moment of return; from the moment the first Infirmary is finished, twice as fast.
const HEAL_POINTS: int = 3
const HEAL_SECONDS: int = 2
## An adventurer in training gains one XP per whole TRAINING_SECONDS_PER_XP since their stint
## started, at most TRAINING_MAX_XP a stint; the cap is the reason to come back (stand-ins).
const TRAINING_SECONDS_PER_XP: int = 6
const TRAINING_MAX_XP: int = 20
## Once an adventurer has trained this many seconds in all, the Training room hints at their growth.
const TRAINING_HINT_SECONDS: int = 20
## Each party back from a quest is a try at it, success or failure: every try adds POINTS_PER_TRY
## to that quest's chance, up to MOST_TRY_POINTS, because the guild learns its tricks.
const POINTS_PER_TRY: int = 1
const MOST_TRY_POINTS: int = 15
## The reputation a party coming home earns the guild on a success, by the quest's rank; a failure
## takes FAILURE_REPUTATION. Reputation never goes below 0.
const REPUTATION: Dictionary[String, int] = {"F": 1, "E": 2, "D": 3}
const FAILURE_REPUTATION: int = 1
## Why an adventurer can't start training while every Training room's one place is taken.
const NO_TRAINING_PLACE: String = "No free training place — convert a Training room"

## Parties out, in the order they left. Each is {"quest": quest id, "since": unix seconds it left,
## "party": adventurer ids, "party_id": the id of the party they are (Parties), missing from one
## sent before only whole parties went, "seed": the seed that fixes how it ends, "chance": its whole-percent
## chance of success when it left, a lucky break counted, "spirit" and "luck": the party's totals
## when it left, "health" and "max_health": {adventurer
## id: points} each member left with}. A party counts as out until the checkpoint after its return
## brings it home.
var outings: Array[Dictionary] = []
## Unix seconds each injured adventurer recovers at. A member who comes home under a quarter of
## their maximum health is injured.
var injured_until: Dictionary[String, int] = {}
## How many seconds each adventurer's latest injury lasts in all, fixed when it was decided.
var injury_lengths: Dictionary[String, int] = {}
## Loot that found the stash full when its party came home, in the order it came, waiting for the
## player to swap it in (`swap_loot`) or let it go (`let_loot_go`), or for the stash to have room at
## a checkpoint, which stows it. Each is {"quest": quest id, "party": adventurer ids, "item": item
## id}. Until it is stowed or decided, its party stays home.
var waiting_loot: Array[Dictionary] = []
## The guild's gold, which a returning party's reward goes into. Whoever loads the game sets it to
## the guild's own Gold before the first checkpoint.
var gold: Gold = Gold.new(0)
## Who is in the guild, and each one's stats, level, XP and gear: their stats decide quests, and
## returns grow them.
var adventurers: Adventurers = Adventurers.new()
## How far each floor of the labyrinth is explored and the materials brought back from it.
var labyrinth: Labyrinth = Labyrinth.new()
## The health each adventurer below their maximum came home with: {"health": points, "at": unix
## seconds they came home}. Their health at home is computed from it; anyone missing is at full
## health.
var wounds: Dictionary[String, Dictionary] = {}
## The story quests a party has come home from successfully, each once, in the order they were.
var story_done: PackedStringArray = PackedStringArray()
## Quests whose unknown challenges a returning party has made known, for good.
var revealed: PackedStringArray = PackedStringArray()
## Unix seconds each adventurer in training started their stint at. Their XP from it is computed
## from this alone and banked when they stop.
var training: Dictionary[String, int] = {}
## Seconds each adventurer has trained in all over stints already stopped.
var trained_seconds: Dictionary[String, int] = {}
## How many parties have come back from each quest, success or failure: see `try_points`.
var tries: Dictionary[String, int] = {}
## The guild's reputation: what returning parties have earned it (REPUTATION), never below 0.
var reputation: int = 0
## Latest unix seconds seen. Time is read as never earlier than this, so a clock set back neither
## adds time to a quest or an injury nor brings back a party that has returned.
var checked_at: int
## The unix seconds the first Infirmary is finished at, as the last checkpoint was told; -1 for none.
var _infirmary_from: int = -1
## Debriefs a save from before returns paid at once still held unread: the next checkpoint pays
## them as if their parties had just come home. Each is as that save wrote it, with "quest",
## "party", "gold", "xp", "loot" (item ids), "xp_given" (whether coming home gave the XP) and
## "kept" (the loot already swapped into the stash).
var _unpaid: Array[Dictionary] = []


func _init(at: int) -> void:
	checked_at = at


## The whole-percent chance that `party`, as they are now, succeeds on `quest_id`, counting every
## challenge, known to the player or not, the guild's tries at it, and a `lucky_break` if it has
## one (Outcome.chance_percent).
func success_chance(quest_id: String, party: PackedStringArray, lucky_break: bool = false) -> int:
	return Outcome.chance_percent(challenge_chances(quest_id, party), try_points(quest_id), lucky_break)


## The chance the player is shown for `party` on `quest_id`, as [low, high] in whole percent: see
## Outcome.chance_range, the guild's tries counted. Once every challenge is known, the true chance
## without a lucky break lies inside.
func chance_range(quest_id: String, party: PackedStringArray) -> Vector2i:
	var unknown := unknown_challenges(quest_id)
	var known: Array[int] = []
	for challenge: String in QUESTS[quest_id]["challenges"]:
		if challenge not in unknown:
			known.append(_challenge_chance(quest_id, challenge, party))
	return Outcome.chance_range(known, unknown.size(), try_points(quest_id))


## The chance in whole percent that `party` meets each challenge of `quest_id`, in QUESTS order.
func challenge_chances(quest_id: String, party: PackedStringArray) -> Array[int]:
	var chances: Array[int] = []
	for challenge: String in QUESTS[quest_id]["challenges"]:
		chances.append(_challenge_chance(quest_id, challenge, party))
	return chances


## True when `party`'s total for `challenge` reaches what it needs on `quest_id`.
func challenge_met(quest_id: String, challenge: String, party: PackedStringArray) -> bool:
	return Challenges.party_total(challenge, party, adventurers) >= Challenges.requirement(challenge, int(QUESTS[quest_id]["difficulty"]))


## The sum of `party`'s `stat`, gear included: what counts for Spirit and Luck, which work for the
## whole party.
func party_stat(party: PackedStringArray, stat: String) -> int:
	var total := 0
	for adventurer: String in party:
		total += adventurers.stat_total(adventurer, stat)
	return total


func _challenge_chance(quest_id: String, challenge: String, party: PackedStringArray) -> int:
	return Outcome.challenge_chance(Challenges.party_total(challenge, party, adventurers), Challenges.requirement(challenge, int(QUESTS[quest_id]["difficulty"])))


## The points the guild's tries at `quest_id` add to its chance: POINTS_PER_TRY a try, at most
## MOST_TRY_POINTS.
func try_points(quest_id: String) -> int:
	return mini(MOST_TRY_POINTS, POINTS_PER_TRY * int(tries.get(quest_id, 0)))


## The challenges of `quest_id` the player doesn't know yet. A quest's last challenge starts
## unknown, unless it is its only one or the quest is a story quest; a party back from the quest
## makes them known for good.
func unknown_challenges(quest_id: String) -> PackedStringArray:
	var challenges: Array = QUESTS[quest_id]["challenges"]
	if quest_id in revealed or challenges.size() < 2 or is_story(quest_id):
		return PackedStringArray()
	return PackedStringArray([challenges[-1]])


## True when `quest_id` is a story quest (QUESTS "story").
static func is_story(quest_id: String) -> bool:
	return QUESTS[quest_id].get("story", false)


## The story quests open to a guild whose goals have unlocked the ids in `unlocked` (Goals.unlocked),
## in QUESTS order: each unlocked and not done, whether or not a party is out on it.
func open_story_quests(unlocked: PackedStringArray) -> PackedStringArray:
	var open := PackedStringArray()
	for quest: String in QUESTS:
		if is_story(quest) and quest in unlocked and quest not in story_done:
			open.append(quest)
	return open


## True when `quest_id` is a board quest set in the labyrinth (QUESTS "labyrinth"), tagged so on
## the board and in the picker; otherwise an ordinary board quest.
static func is_labyrinth(quest_id: String) -> bool:
	return QUESTS[quest_id].get("labyrinth", false)


## True when `quest_id` is a floor of the labyrinth (QUESTS "floor").
static func is_floor(quest_id: String) -> bool:
	return QUESTS[quest_id].has("floor")


## The floors open to a guild whose goals have unlocked the ids in `unlocked` (Goals.unlocked), from
## the top: none until Labyrinth.UNLOCK is unlocked, then floor 1 and each floor after whose floor
## above is at least Labyrinth.NEXT_FLOOR_AT explored, whether or not a party is out on it.
func open_floors(unlocked: PackedStringArray) -> PackedStringArray:
	var open := PackedStringArray()
	if Labyrinth.UNLOCK not in unlocked:
		return open
	for quest: String in QUESTS:
		if not is_floor(quest):
			continue
		if not open.is_empty() and labyrinth.explored_percent(open[-1]) < Labyrinth.NEXT_FLOOR_AT:
			break
		open.append(quest)
	return open


## The gold `_quest_id` brings when it fails: none, so failing costs something.
static func failure_gold(_quest_id: String) -> int:
	return 0


## The XP each member of a party of `size` gains back from a quest whose whole party shares `xp` on
## a success: an equal part of what the outcome gives (Adventurers.quest_xp), rounded down, but at
## least 1, so nobody comes back from a quest with nothing.
static func xp_share(xp: int, success: bool, size: int) -> int:
	return maxi(1, floori(Adventurers.quest_xp(xp, success) / float(size)))


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
## home, what their last return left them with, plus HEAL_POINTS per HEAL_SECONDS since, in whole
## points (twice as fast from the moment the Infirmary is finished), up to their maximum.
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
	var missing := adventurers.max_health(adventurer) - int(wound["health"])
	var need := ceili(missing * HEAL_SECONDS / float(HEAL_POINTS)) - _heal_units(int(wound["at"]), at)
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
	return mini(most, int(wound["health"]) + floori(_heal_units(int(wound["at"]), at) * HEAL_POINTS / float(HEAL_SECONDS)))


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


## Why `adventurer` can't put a stash item on, in words for the player; "" when they can.
func wear_refusal(adventurer: String) -> String:
	return "" if can_change_gear(adventurer) else "Out on a quest"


## Puts the stash item at `index` on `adventurer`, the item it replaces into the stash; false, with
## nothing changed, when wear_refusal gives a reason.
func wear(adventurer: String, index: int) -> bool:
	if not wear_refusal(adventurer).is_empty():
		return false
	adventurers.gear.wear(adventurer, index)
	return true


## Why `adventurer` can't take off what they wear in `slot`, in words for the player; "" when they
## can.
func take_off_refusal(adventurer: String, slot: String) -> String:
	if not can_change_gear(adventurer):
		return "Out on a quest"
	if not adventurers.gear.worn[adventurer].has(slot):
		return "Nothing worn"
	if adventurers.gear.stash.size() >= adventurers.gear.stash_cap:
		return "Stash full"
	return ""


## Puts what `adventurer` wears in `slot` into the stash; false, with nothing changed, when
## take_off_refusal gives a reason.
func take_off(adventurer: String, slot: String) -> bool:
	return take_off_refusal(adventurer, slot).is_empty() and adventurers.gear.take_off(adventurer, slot)


## True when `adventurer` can join a party at `now`: home, no loot of theirs waiting, not injured
## and not training.
func can_go(adventurer: String, now: int) -> bool:
	return quest_of(adventurer).is_empty() and not loot_waiting(adventurer) and injury_left(adventurer, now) == 0 and not training.has(adventurer)


## True when loot a party `adventurer` was in brought to a full stash waits for the player: until
## all of it is decided, they are not available.
func loot_waiting(adventurer: String) -> bool:
	for waiting: Dictionary in waiting_loot:
		if adventurer in waiting["party"]:
			return true
	return false


## Who has a level-up ready, in roster order.
func ready_to_level() -> PackedStringArray:
	var ready := PackedStringArray()
	for adventurer: String in adventurers.roster:
		if adventurers.level_up_ready(adventurer):
			ready.append(adventurer)
	return ready


## How many things wait for the player: each loot waiting, and every level-up ready together as one.
func needs_you_count() -> int:
	return waiting_loot.size() + (0 if ready_to_level().is_empty() else 1)


## What `adventurer` is doing at `now`, in words for the player.
func status(adventurer: String, now: int) -> String:
	var quest := quest_of(adventurer)
	if not quest.is_empty():
		return "On quest: " + QUESTS[quest]["name"]
	if loot_waiting(adventurer):
		return "Waiting on loot"
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
	if loot_waiting(adventurer):
		return "Waiting on loot"
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


## The XP `adventurer`'s current stint has earned by `now`: one per whole TRAINING_SECONDS_PER_XP,
## at most TRAINING_MAX_XP; 0 when not training.
func training_xp(adventurer: String, now: int) -> int:
	if not training.has(adventurer):
		return 0
	return mini(TRAINING_MAX_XP, floori((maxi(now, checked_at) - training[adventurer]) / float(TRAINING_SECONDS_PER_XP)))


## Seconds from `now` until `adventurer`'s stint reaches TRAINING_MAX_XP; 0 once capped or when not
## training.
func training_seconds_left(adventurer: String, now: int) -> int:
	if not training.has(adventurer):
		return 0
	var full_at := training[adventurer] + TRAINING_MAX_XP * TRAINING_SECONDS_PER_XP
	return maxi(0, full_at - maxi(now, checked_at))


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


## The name of the stat `adventurer` grows fastest in, gear counted (Adventurers.growth_chance),
## ties going to the first in Adventurers.STATS, once they have trained TRAINING_HINT_SECONDS in all
## by `now`; "" before. Growth numbers themselves are never shown.
func training_hint(adventurer: String, now: int) -> String:
	if _seconds_trained(adventurer, now) < TRAINING_HINT_SECONDS:
		return ""
	var fastest := ""
	for stat: String in Adventurers.STATS:
		if fastest.is_empty() or adventurers.growth_chance(adventurer, stat) > adventurers.growth_chance(adventurer, fastest):
			fastest = stat
	return Adventurers.STATS[fastest]


# Seconds `adventurer` has trained in all by `now`, the current stint included.
func _seconds_trained(adventurer: String, now: int) -> int:
	var seconds: int = trained_seconds.get(adventurer, 0)
	if training.has(adventurer):
		seconds += maxi(now, checked_at) - training[adventurer]
	return seconds


## Why `adventurer` can't be dismissed, in words for the player; "" when they can. Anyone home can
## leave, but the guild keeps at least one adventurer.
func dismiss_refusal(adventurer: String) -> String:
	if not quest_of(adventurer).is_empty():
		return "Out on a quest"
	if loot_waiting(adventurer):
		return "Waiting on loot"
	if training.has(adventurer):
		return "Training"
	if adventurers.roster.size() <= 1:
		return "The guild's last adventurer"
	return ""


## Dismisses `adventurer` for good: the guild forgets them as if they had never joined, their gear
## going to the stash (Adventurers.remove); false, with nothing changed, when `dismiss_refusal`
## gives a reason. A rank lost
## with them changes which quests the board draws, so whoever calls this brings the board up to date
## first.
func dismiss(adventurer: String) -> bool:
	if not dismiss_refusal(adventurer).is_empty():
		return false
	wounds.erase(adventurer)
	injured_until.erase(adventurer)
	injury_lengths.erase(adventurer)
	trained_seconds.erase(adventurer)
	adventurers.remove(adventurer)
	return true


## Why `party` can't be sent on `quest_id` at `now`, in words for the player; "" when it can.
## However many parties are out, a party goes whole or not at all: `party` must be exactly one
## party's members, each home and well, and the party's rank (Parties.rank) must allow the quest
## (Challenges.can_join). Reserves never go. A story quest or a floor goes once at a time, and a
## story quest never once done.
func party_refusal(quest_id: String, party: PackedStringArray, now: int) -> String:
	if is_story(quest_id) and quest_id in story_done:
		return "Already done"
	if is_story(quest_id) or is_floor(quest_id):
		for outing: Dictionary in outings:
			if outing["quest"] == quest_id:
				return "A party is out on it"
	var id := party_id_of(party)
	if id.is_empty():
		return "Pick a party"
	for adventurer: String in party:
		if not can_go(adventurer, now):
			return "%s can't go" % adventurers.roster[adventurer]["name"]
	if not Challenges.can_join(adventurers.parties.rank(id, adventurers.roster), QUESTS[quest_id]["rank"]):
		return "Party rank too low"
	return ""


## The id of the party whose members are exactly `party`, in any order; "" when no party's are.
func party_id_of(party: PackedStringArray) -> String:
	if party.is_empty():
		return ""
	var id := adventurers.parties.party_of(party[0])
	if id == Parties.RESERVES:
		return ""
	var members: PackedStringArray = adventurers.parties.party(id)["members"].duplicate()
	var asked := party.duplicate()
	members.sort()
	asked.sort()
	return id if members == asked else ""


## Sends `party` on `quest_id` at `now`, its outcome fixed by `roll_seed`; false, with nothing
## started, when `party_refusal` gives a reason. Which board quests can be sent is Board's rule;
## which story quests, `open_story_quests`; which floors, `open_floors`.
## `infirmary_from` is as for `checkpoint`.
func send(quest_id: String, party: PackedStringArray, roll_seed: int, now: int, infirmary_from: int = -1) -> bool:
	checkpoint(now, infirmary_from)
	if not party_refusal(quest_id, party, now).is_empty():
		return false
	# Health is fixed on leaving, like the chance, so a level-up while out changes nothing about how
	# the quest ends.
	var health_left_with := {}
	var max_left_with := {}
	for adventurer: String in party:
		health_left_with[adventurer] = health(adventurer, checked_at)
		max_left_with[adventurer] = adventurers.max_health(adventurer)
	# A lucky break is decided by the seed now, and only counts when it lifts the weakest challenge.
	var luck := party_stat(party, "luck")
	var lucky: bool = Outcome.lucky_break(roll_seed, luck) and challenge_chances(quest_id, party).min() < Outcome.EVEN_CHANCE
	outings.append({"quest": quest_id, "since": checked_at, "party": party.duplicate(), "party_id": party_id_of(party), "seed": roll_seed, "chance": success_chance(quest_id, party, lucky), "spirit": party_stat(party, "spirit"), "luck": luck, "health": health_left_with, "max_health": max_left_with})
	return true


## True when a party returned after the last checkpoint: the "while you were away" news when the
## checkpoint was taken on leaving. Its outcome is applied at the next checkpoint.
func returned_since_checkpoint(now: int) -> bool:
	for outing: Dictionary in outings:
		if seconds_left(outing, now) == 0:
			return true
	return false


## Stows the loot waiting, oldest first, as far as the stash has room, freeing its parties. Then
## brings every returned party home, once, in the order they returned: gives each member damage and
## XP and, on a success, counts it for them (Adventurers.successes), gives the guild its reputation
## (REPUTATION, or the quest's own) and marks a story quest done, adds a floor's exploring and
## material (Labyrinth.bring_home), injures those it leaves under a
## quarter of their health, reveals the quest's challenges, puts the gold it earned into `gold` and
## its loot into the stash, where loot that finds it full waits (`waiting_loot`). Debriefs a save from before held unread are paid first, the same way.
## `infirmary_from` is the unix seconds the first Infirmary is finished at, -1 for none: from then
## on healing is faster, and an injury from a return at or after it is shorter. Records the time
## seen.
func checkpoint(now: int, infirmary_from: int = -1) -> void:
	checked_at = maxi(checked_at, now)
	_infirmary_from = infirmary_from
	# Before any return, so loot that has waited longest takes the room first.
	while not waiting_loot.is_empty() and adventurers.gear.stow(waiting_loot[0]["item"]):
		waiting_loot.remove_at(0)
	for debrief: Dictionary in _unpaid:
		gold.amount += int(debrief["gold"])
		if not debrief.get("xp_given", false):
			for adventurer: String in debrief["party"]:
				adventurers.gain_xp(adventurer, int(debrief["xp"]))
		var items: PackedStringArray = debrief["loot"].duplicate()
		for kept: String in debrief.get("kept", PackedStringArray()):
			items.remove_at(items.find(kept))
		for item: String in items:
			_stow_or_wait(debrief["quest"], debrief["party"], item)
	_unpaid.clear()
	var returned: Array[Dictionary] = []
	for outing: Dictionary in outings:
		if seconds_left(outing, checked_at) == 0:
			returned.append(outing)
	returned.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return back_at(a) < back_at(b))
	for outing: Dictionary in returned:
		outings.erase(outing)
		_bring_home(outing)


func _bring_home(outing: Dictionary) -> void:
	var quest: Dictionary = QUESTS[outing["quest"]]
	var party: PackedStringArray = outing["party"]
	var returns_at := back_at(outing)
	var reward: int = quest["gold"]
	var success := true
	# Spirit and Luck are the party's when it left, so a level-up while out changes nothing. One sent
	# before they were kept counts the party's now.
	var luck: int = outing.get("luck", party_stat(party, "luck"))
	# A party sent before adventurers existed has no members: it comes home as it was sent then,
	# earning its reward in full.
	if not party.is_empty():
		# The chance is the one it left with, so a level-up while out never changes how it ends. One
		# sent before chances were kept rolls with the stats it has now, which are the stats it had
		# then: nobody could level up before.
		var chance: int = outing.get("chance", success_chance(outing["quest"], party))
		var outcome := Outcome.roll(outing["seed"], chance, Outcome.MOST_DAMAGE[quest["rank"]], party, outing.get("spirit", party_stat(party, "spirit")), luck)
		success = outcome.success
		if not success:
			reward = failure_gold(outing["quest"])
		var damage := outcome.damage
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
	if not unknown_challenges(outing["quest"]).is_empty():
		revealed.append(outing["quest"])
	tries[outing["quest"]] = int(tries.get(outing["quest"], 0)) + 1
	# A party with no members gains nothing.
	if not party.is_empty():
		var xp := xp_share(quest["xp"], success, party.size())
		for adventurer: String in party:
			adventurers.gain_xp(adventurer, xp)
			if success:
				adventurers.add_successes(adventurer, quest["rank"], 1)
	gold.amount += reward
	reputation = maxi(0, reputation + (int(quest.get("reputation", REPUTATION[quest["rank"]])) if success else -FAILURE_REPUTATION))
	if success and is_story(outing["quest"]) and outing["quest"] not in story_done:
		story_done.append(outing["quest"])
	if is_floor(outing["quest"]):
		labyrinth.bring_home(outing["quest"], success, gold)
	# Loot comes whatever the outcome, from the seed the party left with.
	var item := Gear.loot(outing["seed"], quest["rank"], luck)
	if not item.is_empty():
		_stow_or_wait(outing["quest"], party, item)


# Puts `item`, which `party` brought back from `quest`, into the stash; when the stash is full, it
# waits for the player instead.
func _stow_or_wait(quest: String, party: PackedStringArray, item: String) -> void:
	if not adventurers.gear.stow(item):
		waiting_loot.append({"quest": quest, "party": party, "item": item})


## Sells `stash_item` from the stash at its price (Gear.price) into `gold` and stows the loot waiting
## at `index` in its place, freeing its party; false, with nothing changed, when the stash holds no
## `stash_item`.
func swap_loot(index: int, stash_item: String) -> bool:
	if not adventurers.gear.sell(stash_item, gold):
		return false
	adventurers.gear.stow(waiting_loot[index]["item"])
	waiting_loot.remove_at(index)
	return true


## Discards the loot waiting at `index` for good, freeing its party.
func let_loot_go(index: int) -> void:
	waiting_loot.remove_at(index)


## Unix seconds `outing`'s party is back, fixed when it leaves.
func back_at(outing: Dictionary) -> int:
	return int(outing["since"]) + int(QUESTS[outing["quest"]]["seconds"])


## Puts the dispatch into `file`, which other state shares, so one save holds the whole game.
func write(file: ConfigFile) -> void:
	file.set_value("dispatch", "outings", outings)
	file.set_value("dispatch", "injured_until", injured_until)
	file.set_value("dispatch", "injury_lengths", injury_lengths)
	file.set_value("dispatch", "waiting_loot", waiting_loot)
	file.set_value("dispatch", "wounds", wounds)
	file.set_value("dispatch", "revealed", revealed)
	file.set_value("dispatch", "story_done", story_done)
	file.set_value("dispatch", "training", training)
	file.set_value("dispatch", "trained_seconds", trained_seconds)
	file.set_value("dispatch", "tries", tries)
	file.set_value("dispatch", "reputation", reputation)
	file.set_value("dispatch", "checked_at", checked_at)
	adventurers.write(file)
	labyrinth.write(file)


## The dispatch saved at `path`, or everyone home and well at `now` when the save has none.
static func load_or_start(path: String, now: int) -> Dispatch:
	var dispatch := Dispatch.new(now)
	dispatch.adventurers = Adventurers.load_or_start(path)
	dispatch.labyrinth = Labyrinth.load_or_start(path)
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
	dispatch.waiting_loot.assign(file.get_value("dispatch", "waiting_loot", []))
	# A save from before returns paid at once holds those it had not paid yet as debriefs with "paid"
	# false; the next checkpoint pays them. Older debriefs were paid when their party came home.
	for debrief: Dictionary in file.get_value("dispatch", "debriefs", []):
		if not debrief.get("paid", true):
			dispatch._unpaid.append(debrief)
	# A save from before health has nobody hurt: everyone loads at full health.
	dispatch.wounds.assign(file.get_value("dispatch", "wounds", {}))
	# A save from before challenges were known knows what every new guild knows.
	dispatch.revealed = file.get_value("dispatch", "revealed", PackedStringArray())
	# A save from before story quests has finished none.
	dispatch.story_done = file.get_value("dispatch", "story_done", PackedStringArray())
	# A save from before training has nobody training and nobody trained.
	dispatch.training.assign(file.get_value("dispatch", "training", {}))
	dispatch.trained_seconds.assign(file.get_value("dispatch", "trained_seconds", {}))
	# A save from before tries were counted has tried nothing.
	dispatch.tries.assign(file.get_value("dispatch", "tries", {}))
	# A save from before reputation has earned none.
	dispatch.reputation = int(file.get_value("dispatch", "reputation", 0))
	dispatch.checked_at = int(file.get_value("dispatch", "checked_at", now))
	return dispatch
