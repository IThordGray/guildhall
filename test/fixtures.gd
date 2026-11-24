extends RefCounted

## What several test files set up the same way.


## Makes `members` of `dispatch` a party of their own, as moving them there would, though
## someone may be out, and returns them, so a test can send them as one. Members already exactly one
## party stay in it; none, or more than a party holds, stay as they are, to be refused.
static func party(dispatch: Dispatch, members: PackedStringArray) -> PackedStringArray:
	var parties := dispatch.adventurers.parties
	if members.is_empty() or members.size() > Dispatch.MAX_PARTY_SIZE:
		return members
	var current := parties.party(parties.party_of(members[0]))
	if not current.is_empty() and current["members"].size() == members.size():
		var whole := true
		for adventurer: String in members:
			whole = whole and adventurer in current["members"]
		if whole:
			return members
	for adventurer: String in members:
		parties.leave(adventurer)
	parties.parties.append({"id": "party_%d" % parties.next_id, "name": Parties.name_of(parties.next_id), "seed": parties.next_id, "members": members.duplicate()})
	parties.next_id += 1
	return members
