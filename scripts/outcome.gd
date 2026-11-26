class_name Outcome
extends RefCounted

## How a quest ends. It depends only on the seed, chance, most damage and party it is rolled from,
## so a quest's end is fixed the moment it is sent and rolling it again gives the same answer.

## No chance is surer than this nor more hopeless than MIN_CHANCE, in whole percent.
const MAX_CHANCE: int = 95
const MIN_CHANCE: int = 5
## A challenge's chance is EVEN_CHANCE when the party's total meets its requirement exactly, and
## moves CHANCE_PER_POINT for each point of difference.
const EVEN_CHANCE: int = 50
const CHANCE_PER_POINT: int = 2
## How far each end of the chance range the player sees is widened, because the difficulty is
## hidden.
const HIDDEN_DIFFICULTY_POINTS: int = 10
## The most damage a failed quest of each rank deals a member (stand-ins): enough that a failed E
## quest can injure from full health, while a successful F quest never does.
const MOST_DAMAGE: Dictionary[String, int] = {"F": 16, "E": 30, "D": 48, "C": 70}
## The party's total Spirit takes this many percent off the damage each member takes, at most
## MOST_SPIRIT_CUT (stand-ins): the four starters together take about what a party with a Healer
## once did.
const SPIRIT_CUT_PER_POINT: int = 2
const MOST_SPIRIT_CUT: int = 50
## On a failure, the party's total Luck takes this many percent more off, at most MOST_LUCK_CUT
## (stand-ins).
const LUCK_CUT_PER_POINT: int = 2
const MOST_LUCK_CUT: int = 30
## The chance in whole percent that a party gets a lucky break, per point of its total Luck, at most
## MOST_LUCKY_BREAK_PERCENT (stand-ins). A lucky break counts the party's weakest challenge at
## EVEN_CHANCE when it is below that.
const LUCKY_BREAK_PERCENT_PER_POINT: int = 2
const MOST_LUCKY_BREAK_PERCENT: int = 25

var success: bool = true
## The damage the quest deals each member: 0 to most ÷ 2 on success, most ÷ 2 to most on failure,
## most being the quest's MOST_DAMAGE; less by the party's Spirit, and on a failure its Luck.
var damage: Dictionary = {}


## The chance in whole percent of meeting a challenge that needs `requirement` with a party total
## of `total`: EVEN_CHANCE when they are equal, CHANCE_PER_POINT per point of difference, within
## MIN_CHANCE to MAX_CHANCE.
static func challenge_chance(total: int, requirement: int) -> int:
	return clampi(EVEN_CHANCE + CHANCE_PER_POINT * (total - requirement), MIN_CHANCE, MAX_CHANCE)


## A quest's chance of success in whole percent from its `challenge_chances`: their average, with
## the weakest counted twice, rounded down, then `bonus` points on, within MIN_CHANCE to MAX_CHANCE.
## With `lucky_break`, the weakest counts at EVEN_CHANCE when it is below it.
static func chance_percent(challenge_chances: Array[int], bonus: int = 0, lucky_break: bool = false) -> int:
	var chances := challenge_chances.duplicate()
	if lucky_break:
		# One challenge only, never above even.
		var weakest_at := chances.find(chances.min())
		chances[weakest_at] = maxi(chances[weakest_at], EVEN_CHANCE)
	var total: int = chances.min()
	for chance: int in chances:
		total += chance
	var average := floori(total / float(chances.size() + 1))
	return clampi(average + bonus, MIN_CHANCE, MAX_CHANCE)


## The chance the player is shown, as [low, high] in whole percent: the chance from the `known`
## challenges' chances with `bonus` points on, each of the `unknown` challenges counted as an even
## match (EVEN_CHANCE), widened HIDDEN_DIFFICULTY_POINTS either way, within MIN_CHANCE to
## MAX_CHANCE. A lucky break is left out. Narrow over sure: while a challenge is unknown the true
## chance may fall outside; once all are known, the true chance without a lucky break is inside.
static func chance_range(known: Array[int], unknown: int, bonus: int = 0) -> Vector2i:
	var chances := known.duplicate()
	for each: int in unknown:
		chances.append(EVEN_CHANCE)
	var middle := chance_percent(chances, bonus)
	return Vector2i(clampi(middle - HIDDEN_DIFFICULTY_POINTS, MIN_CHANCE, MAX_CHANCE), clampi(middle + HIDDEN_DIFFICULTY_POINTS, MIN_CHANCE, MAX_CHANCE))


## True when a party with `luck` in all, sent with `roll_seed`, gets a lucky break:
## LUCKY_BREAK_PERCENT_PER_POINT per point, at most MOST_LUCKY_BREAK_PERCENT. Uses its own
## generator, never the global one.
static func lucky_break(roll_seed: int, luck: int) -> bool:
	var rng := RandomNumberGenerator.new()
	# Not the outcome's own sequence, so a lucky break leaves the roll as it was.
	rng.seed = hash("lucky:%d" % roll_seed)
	return rng.randi_range(1, 100) <= mini(MOST_LUCKY_BREAK_PERCENT, LUCKY_BREAK_PERCENT_PER_POINT * luck)


## The outcome `roll_seed` gives `party`, with `chance` percent of success on a quest that deals
## at most `most_damage`, the party having `spirit` and `luck` in all. Uses its own generator, never
## the global one, so nothing else that draws random numbers can change it.
static func roll(roll_seed: int, chance: int, most_damage: int, party: PackedStringArray, spirit: int = 0, luck: int = 0) -> Outcome:
	var rng := RandomNumberGenerator.new()
	rng.seed = roll_seed
	var outcome := Outcome.new()
	outcome.success = rng.randi_range(1, 100) <= chance
	var half := floori(most_damage / 2.0)
	var spirit_cut := mini(MOST_SPIRIT_CUT, SPIRIT_CUT_PER_POINT * spirit)
	var luck_cut := 0 if outcome.success else mini(MOST_LUCK_CUT, LUCK_CUT_PER_POINT * luck)
	# What members take of the damage rolled, in hundredths of a percent.
	var kept := (100 - spirit_cut) * (100 - luck_cut)
	for adventurer: String in party:
		var dealt := rng.randi_range(0, half) if outcome.success else rng.randi_range(half, most_damage)
		outcome.damage[adventurer] = floori(dealt * kept / 10_000.0)
	return outcome
