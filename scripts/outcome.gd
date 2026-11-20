class_name Outcome
extends RefCounted

## How a quest ends. It depends only on the seed, chance, difficulty and party it is rolled from,
## so a quest's end is fixed the moment it is sent and rolling it again gives the same answer.

## No chance is surer than this nor more hopeless than MIN_CHANCE, in whole percent.
const MAX_CHANCE: int = 95
const MIN_CHANCE: int = 5
## Points off the chance for each of a quest's challenges no member covers.
const UNCOVERED_POINTS: int = 15
## How far each end of the chance range the player sees is widened, because the difficulty is
## hidden.
const HIDDEN_DIFFICULTY_POINTS: int = 10

var success: bool = true
## The damage the quest deals each member: 0 to difficulty ÷ 2 on success, difficulty ÷ 2 to
## difficulty on failure (stand-ins); half that, rounded down, when a Healer is in the party.
var damage: Dictionary = {}


## Chance of success in whole percent: even odds when the party's power matches the difficulty,
## 10 points per point of difference, then UNCOVERED_POINTS off for each of `uncovered` challenges
## nobody covers; each step kept within MIN_CHANCE to MAX_CHANCE.
static func chance_percent(party_power: int, difficulty: int, uncovered: int = 0) -> int:
	var by_power := clampi(50 + 10 * (party_power - difficulty), MIN_CHANCE, MAX_CHANCE)
	return clampi(by_power - UNCOVERED_POINTS * uncovered, MIN_CHANCE, MAX_CHANCE)


## The chance the player is shown, as [low, high] in whole percent, for a party of `party_power`
## on a quest of `difficulty` with `uncovered` known challenges nobody covers and `unknown`
## challenges the player doesn't know: low counts every unknown one uncovered, high counts it
## covered, and each end is widened by HIDDEN_DIFFICULTY_POINTS, within MIN_CHANCE to MAX_CHANCE.
static func chance_range(party_power: int, difficulty: int, uncovered: int, unknown: int) -> Vector2i:
	var low := chance_percent(party_power, difficulty, uncovered + unknown) - HIDDEN_DIFFICULTY_POINTS
	var high := chance_percent(party_power, difficulty, uncovered) + HIDDEN_DIFFICULTY_POINTS
	return Vector2i(clampi(low, MIN_CHANCE, MAX_CHANCE), clampi(high, MIN_CHANCE, MAX_CHANCE))


## The outcome `roll_seed` gives `party`, whose classes are as `roster` (Adventurers.roster) has
## them, with `chance` percent of success on a quest of `difficulty`. Uses its own generator, never
## the global one, so nothing else that draws random numbers can change it.
static func roll(roll_seed: int, chance: int, difficulty: int, party: PackedStringArray, roster: Dictionary) -> Outcome:
	var rng := RandomNumberGenerator.new()
	rng.seed = roll_seed
	var outcome := Outcome.new()
	outcome.success = rng.randi_range(1, 100) <= chance
	var half := floori(difficulty / 2.0)
	var healed := false
	for adventurer: String in party:
		healed = healed or Dispatch.is_healer(roster[adventurer])
	for adventurer: String in party:
		var dealt := rng.randi_range(0, half) if outcome.success else rng.randi_range(half, difficulty)
		outcome.damage[adventurer] = floori(dealt / 2.0) if healed else dealt
	return outcome
