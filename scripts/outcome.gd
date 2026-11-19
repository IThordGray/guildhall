class_name Outcome
extends RefCounted

## How a quest ends. It depends only on the seed, chance, difficulty and party it is rolled from,
## so a quest's end is fixed the moment it is sent and rolling it again gives the same answer.

var success: bool = true
## The damage the quest deals each member: 0 to difficulty ÷ 2 on success, difficulty ÷ 2 to
## difficulty on failure (stand-ins).
var damage: Dictionary = {}


## Chance of success in whole percent: even odds when the party's power matches the difficulty,
## 10 points per point of difference, never surer than 95 nor more hopeless than 5.
static func chance_percent(party_power: int, difficulty: int) -> int:
	return clampi(50 + 10 * (party_power - difficulty), 5, 95)


## The outcome `roll_seed` gives `party` with `chance` percent of success on a quest of
## `difficulty`. Uses its own generator, never the global one, so nothing else that draws random
## numbers can change it.
static func roll(roll_seed: int, chance: int, difficulty: int, party: PackedStringArray) -> Outcome:
	var rng := RandomNumberGenerator.new()
	rng.seed = roll_seed
	var outcome := Outcome.new()
	outcome.success = rng.randi_range(1, 100) <= chance
	var half := floori(difficulty / 2.0)
	for adventurer: String in party:
		outcome.damage[adventurer] = rng.randi_range(0, half) if outcome.success else rng.randi_range(half, difficulty)
	return outcome
