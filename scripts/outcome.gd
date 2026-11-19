class_name Outcome
extends RefCounted

## How a quest ends. It depends only on the seed, chance and party it is rolled from, so a quest's
## end is fixed the moment it is sent and rolling it again gives the same answer.

var success: bool = true
## The party member a failure injures; "" on success.
var injured: String = ""


## Chance of success in whole percent: even odds when the party's power matches the difficulty,
## 10 points per point of difference, never surer than 95 nor more hopeless than 5.
static func chance_percent(party_power: int, difficulty: int) -> int:
	return clampi(50 + 10 * (party_power - difficulty), 5, 95)


## The outcome `roll_seed` gives a non-empty `party` with `chance` percent of success. Uses its own
## generator, never the global one, so nothing else that draws random numbers can change it.
static func roll(roll_seed: int, chance: int, party: PackedStringArray) -> Outcome:
	var rng := RandomNumberGenerator.new()
	rng.seed = roll_seed
	var outcome := Outcome.new()
	outcome.success = rng.randi_range(1, 100) <= chance
	if not outcome.success:
		outcome.injured = party[rng.randi_range(0, party.size() - 1)]
	return outcome
