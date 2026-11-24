class_name Challenges
extends RefCounted

## What makes a quest hard, and which stats deal with it. Each quest's challenges are in
## Dispatch.QUESTS; each challenge has its own chance (see Outcome).

## Ranks from lowest to highest, for adventurers and quests alike.
const RANKS: PackedStringArray = ["F", "E", "D", "C", "B", "A", "S"]
## The stats each challenge tests, with their weights: it is met by the sum, over the whole party,
## of each member's stat (gear included) times its weight. Luck is never tested.
const WEIGHTS: Dictionary[String, Dictionary] = {
	"Brute force": {"strength": 2, "defence": 1},
	"Traps": {"perception": 2, "agility": 1},
	"Navigation": {"perception": 1, "mind": 1},
	"Curse": {"mind": 2, "spirit": 1},
	"Protect": {"defence": 2, "presence": 1},
	"Attrition": {"endurance": 2, "spirit": 1},
	"Negotiation": {"presence": 2, "mind": 1},
}
## A challenge whose weights add up to this needs a party total of exactly the quest's difficulty;
## one weighing more or less needs that much more or less.
const DIFFICULTY_WEIGHT: int = 3


## The total `party` brings to `challenge`: each member's stats in `adventurers`, gear included,
## times their weights in WEIGHTS.
static func party_total(challenge: String, party: PackedStringArray, adventurers: Adventurers) -> int:
	var total := 0
	for adventurer: String in party:
		for stat: String in WEIGHTS[challenge]:
			total += int(WEIGHTS[challenge][stat]) * adventurers.stat_total(adventurer, stat)
	return total


## The party total `challenge` needs on a quest of `difficulty` (Dispatch.QUESTS) to be met.
static func requirement(challenge: String, difficulty: int) -> int:
	var weight := 0
	for stat: String in WEIGHTS[challenge]:
		weight += int(WEIGHTS[challenge][stat])
	return roundi(difficulty * weight / float(DIFFICULTY_WEIGHT))


## True when a party of `party_rank` (Parties.rank) may take a quest of `quest_rank`: at most one
## rank above its own.
static func can_join(party_rank: String, quest_rank: String) -> bool:
	return RANKS.find(quest_rank) <= RANKS.find(party_rank) + 1
