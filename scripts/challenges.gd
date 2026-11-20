class_name Challenges
extends RefCounted

## What makes a quest hard, and which classes deal with it. Each quest's challenges are in
## Dispatch.QUESTS; a challenge no member of a party covers lowers its chance (see Outcome).

## Ranks from lowest to highest, for adventurers and quests alike.
const RANKS: PackedStringArray = ["F", "E", "D", "C", "B", "A", "S"]
## The challenges each class covers (stand-ins).
const COVERS: Dictionary[String, Array] = {
	"Swordsman": ["Brute force"],
	"Mage": ["Curse"],
	"Scout": ["Traps", "Navigation"],
	"Healer": ["Attrition"],
	"Shield bearer": ["Protect"],
}


## The members of `party` who cover `challenge`, in party order; empty when nobody does. Their
## classes are as `roster` (Adventurers.roster) has them.
static func covered_by(challenge: String, party: PackedStringArray, roster: Dictionary) -> PackedStringArray:
	var covering := PackedStringArray()
	for adventurer: String in party:
		if challenge in COVERS.get(roster[adventurer]["class"], []):
			covering.append(adventurer)
	return covering


## True when an adventurer of `adventurer_rank` may join a quest of `quest_rank`: at most one rank
## above their own.
static func can_join(adventurer_rank: String, quest_rank: String) -> bool:
	return RANKS.find(quest_rank) <= RANKS.find(adventurer_rank) + 1
