class_name Outcome
extends RefCounted

## How a quest ends. It depends only on the seed, chance, most damage and party it is rolled from,
## so a quest's end is fixed the moment it is sent and rolling it again gives the same answer.

## No chance is surer than this nor more hopeless than MIN_CHANCE, in whole percent.
const MAX_CHANCE: int = 95
const MIN_CHANCE: int = 5
## Points off the chance for each of a quest's challenges no member covers.
const UNCOVERED_POINTS: int = 15
## How far each end of the chance range the player sees is widened, because the difficulty is
## hidden.
const HIDDEN_DIFFICULTY_POINTS: int = 10
## The most damage a failed quest of each rank deals a member (stand-ins): enough that a failed E
## quest can injure from full health, while a successful F quest never does.
const MOST_DAMAGE: Dictionary[String, int] = {"F": 16, "E": 30, "D": 48}

var success: bool = true
## The damage the quest deals each member: 0 to most ÷ 2 on success, most ÷ 2 to most on failure,
## most being the quest's MOST_DAMAGE; half that, rounded down, when a Healer is in the party.
var damage: Dictionary = {}


## Chance of success in whole percent: even odds when the party's power matches the difficulty,
## 10 points per point of difference, then UNCOVERED_POINTS off for each of `uncovered` challenges
## nobody covers, then `bonus` points on; each step kept within MIN_CHANCE to MAX_CHANCE.
static func chance_percent(party_power: int, difficulty: int, uncovered: int = 0, bonus: int = 0) -> int:
	var by_power := clampi(50 + 10 * (party_power - difficulty), MIN_CHANCE, MAX_CHANCE)
	var by_cover := clampi(by_power - UNCOVERED_POINTS * uncovered, MIN_CHANCE, MAX_CHANCE)
	return clampi(by_cover + bonus, MIN_CHANCE, MAX_CHANCE)


## The chance the player is shown, as [low, high] in whole percent, for a party of `party_power`
## on a quest of `difficulty` with `uncovered` known challenges nobody covers, `unknown`
## challenges the player doesn't know and `bonus` points on: low counts every unknown one
## uncovered, high counts it covered, and each end is widened by HIDDEN_DIFFICULTY_POINTS, within
## MIN_CHANCE to MAX_CHANCE.
static func chance_range(party_power: int, difficulty: int, uncovered: int, unknown: int, bonus: int = 0) -> Vector2i:
	var low := chance_percent(party_power, difficulty, uncovered + unknown, bonus) - HIDDEN_DIFFICULTY_POINTS
	var high := chance_percent(party_power, difficulty, uncovered, bonus) + HIDDEN_DIFFICULTY_POINTS
	return Vector2i(clampi(low, MIN_CHANCE, MAX_CHANCE), clampi(high, MIN_CHANCE, MAX_CHANCE))


## The outcome `roll_seed` gives `party`, whose classes are as `roster` (Adventurers.roster) has
## them, with `chance` percent of success on a quest that deals at most `most_damage`. Uses its own
## generator, never the global one, so nothing else that draws random numbers can change it.
static func roll(roll_seed: int, chance: int, most_damage: int, party: PackedStringArray, roster: Dictionary) -> Outcome:
	var rng := RandomNumberGenerator.new()
	rng.seed = roll_seed
	var outcome := Outcome.new()
	outcome.success = rng.randi_range(1, 100) <= chance
	var half := floori(most_damage / 2.0)
	var healed := false
	for adventurer: String in party:
		healed = healed or Dispatch.is_healer(roster[adventurer])
	for adventurer: String in party:
		var dealt := rng.randi_range(0, half) if outcome.success else rng.randi_range(half, most_damage)
		outcome.damage[adventurer] = floori(dealt / 2.0) if healed else dealt
	return outcome
