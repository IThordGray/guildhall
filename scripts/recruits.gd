class_name Recruits
extends RefCounted

## The candidates visiting the guild, each in a slot of their own until hired. Hiring one empties
## their slot, which refills on its own countdown.

## The most candidates who visit at once, however many Common rooms the guild has.
const MAX_CANDIDATE_SLOTS: int = 4
## How long a slot takes to refill after its candidate is hired.
const CANDIDATE_REFILL_SECONDS: int = 60
## What a hire costs.
const HIRE_GOLD: int = 100
## The rank every candidate starts at.
const RANK: String = "F"
## Once the first Common room is finished, the share of candidates arriving from then on who are
## rank E instead, and what hiring one of them costs.
const RANK_E_CHANCE: float = 0.25
const HIRE_GOLD_E: int = 180
## How many of a candidate's stats show before they are hired; the others show "?".
const STATS_SHOWN: int = 4
## The first names candidates are given.
const NAMES: PackedStringArray = [
	"Aldric", "Alys", "Bryn", "Cael", "Corwin", "Dagny", "Edda", "Elspeth", "Fenn", "Garrick",
	"Hesper", "Hollis", "Idris", "Joss", "Kestrel", "Linnea", "Lorcan", "Mabon", "Nell", "Odile",
	"Osric", "Perrin", "Quill", "Rowan", "Sigrun", "Talia", "Tamsin", "Ulric", "Vesna", "Yara",
]
## What a candidate leans toward: the two stats of a title in Adventurers.PAIR_TITLES, and the
## Standard weapon they arrive wearing for it. They join with LEANING_STAT in those two and
## OTHER_STAT in the rest, each up to STAT_SPREAD either side, growing in them with LEANING_GROWTH
## and OTHER_GROWTH.
const LEANING_WEAPONS: Dictionary[String, String] = {
	"Fighter": "short_sword", "Scout": "hunting_bow", "Mystic": "oak_staff",
	"Cleric": "bell_mace", "Ranger": "hunting_bow", "Envoy": "oak_staff",
	"Paladin": "bell_mace", "Duellist": "short_sword", "Cartographer": "hunting_bow",
}
const LEANING_STAT: int = 6
const OTHER_STAT: int = 3
const LEANING_GROWTH: float = 0.6
const OTHER_GROWTH: float = 0.25
const STAT_SPREAD: int = 1
## The share of candidates who are late bloomers: each stat LATE_BLOOMER_STAT_LOSS below what it
## would be, never under 1, but growth in the first stat of their leaning of LATE_BLOOMER_GROWTH.
const LATE_BLOOMER_CHANCE: float = 0.1
const LATE_BLOOMER_STAT_LOSS: int = 2
const LATE_BLOOMER_GROWTH: float = 0.95

## Each slot's candidate, {} while it refills: {"who": as Adventurers.roster keeps it, face_seed
## included, "stats" and "growth": as Adventurers.add takes them, "shown": the stats shown
## before hiring, "worn": what they wear, {slot: item id} as Gear.worn keeps it}, and for a rank-E
## one "level": the level they arrive and are hired at.
var candidates: Array[Dictionary] = []
## Unix seconds each slot's candidate arrived, or, while it refills, arrives.
var refill_at: PackedInt64Array = PackedInt64Array()
## Latest unix seconds the slots have been refilled up to.
var checked_at: int = 0
## How many candidates visit at once with no Common room, as the Reception gives it
## (Hall.reception); each finished one adds a slot, up to MAX_CANDIDATE_SLOTS in all. Not saved:
## whoever loads the game sets it from the hall.
var reception_slots: int = Hall.LAYOUTS[Hall.NEW_LAYOUT]["candidate_slots"]


## Brings the slots up to `now`: adds a slot for each Common room finished, its first candidate due
## at the room's finish time in `common_rooms_done`, and fills each empty slot whose time has come,
## in the order their time comes. Each candidate is drawn from their slot and arrival time alone,
## never the global generator, so refilling once after an absence gives the same candidates as
## refilling every second through it; one arriving at or after the first Common room finished may
## be rank E. Nobody arriving is named after `walk_in_name`, the walk-in waiting (see WalkIns), if
## any. Time is read as no earlier than the slots last saw, so a clock set back never undoes a refill
## or restarts a countdown. A new guild starts with every slot filled.
func refill(adventurers: Adventurers, now: int, common_rooms_done: PackedInt64Array = PackedInt64Array(), walk_in_name: String = "") -> void:
	var at := maxi(now, checked_at)
	if candidates.is_empty():
		for slot: int in reception_slots:
			candidates.append({})
			refill_at.append(at)
	var rooms := common_rooms_done.duplicate()
	rooms.sort()
	for i: int in range(candidates.size() - reception_slots, mini(rooms.size(), MAX_CANDIDATE_SLOTS - reception_slots)):
		candidates.append({})
		refill_at.append(rooms[i])
	var better_from := -1 if rooms.is_empty() else rooms[0]
	while true:
		var next := -1
		for slot: int in candidates.size():
			if candidates[slot].is_empty() and refill_at[slot] <= at and (next == -1 or refill_at[slot] < refill_at[next]):
				next = slot
		if next == -1:
			break
		var taken := names_taken(adventurers, next)
		if not walk_in_name.is_empty():
			taken.append(walk_in_name)
		candidates[next] = candidate_for(next, refill_at[next], taken, better_from)
	checked_at = at


## Seconds from `now` until empty slot `slot` refills.
func seconds_to_refill(slot: int, now: int) -> int:
	return maxi(0, refill_at[slot] - maxi(now, checked_at))


## Seconds from `now` until the soonest empty slot refills; -1 when no slot is empty.
func seconds_to_next_refill(now: int) -> int:
	var soonest := -1
	for slot: int in candidates.size():
		if candidates[slot].is_empty() and (soonest == -1 or seconds_to_refill(slot, now) < soonest):
			soonest = seconds_to_refill(slot, now)
	return soonest


## What hiring `candidate` costs: more for a rank-E one.
static func hire_gold(candidate: Dictionary) -> int:
	return HIRE_GOLD_E if candidate["who"]["rank"] == "E" else HIRE_GOLD


## Why nobody costing `cost` can be hired into `adventurers` with `gold` and `beds`, in words for
## the player; "" when they can. A Bunk room is suggested only while `hall` can still build one:
## none built or being built, and the guild's rank opens it.
static func refusal(adventurers: Adventurers, gold: Gold, beds: int, cost: int = HIRE_GOLD, hall: Hall = null) -> String:
	var no_bed := bed_refusal(adventurers, beds, hall)
	if not no_bed.is_empty():
		return no_bed
	if gold.amount < cost:
		return "Not enough gold"
	return ""


## Why nobody can join `adventurers` with `beds`, in words for the player; "" while a bed is free.
## `hall` is as for `refusal`.
static func bed_refusal(adventurers: Adventurers, beds: int, hall: Hall = null) -> String:
	if adventurers.roster.size() >= beds:
		var bunk_room_open := hall != null and hall.has_rank(Hall.ROOM_TYPES["bunk_room"]["rank"]) and hall.first_room("bunk_room").is_empty()
		return "No free bed — convert a Bunk room" if bunk_room_open else "No free bed"
	return ""


## Pays `hire_gold` and brings the candidate in `slot` at `now` into `adventurers`, emptying the
## slot until CANDIDATE_REFILL_SECONDS later; false, with nothing paid or hired, when the slot is
## empty or `refusal` gives a reason. `common_rooms_done` and `walk_in_name` are as for `refill`.
func hire(slot: int, adventurers: Adventurers, gold: Gold, beds: int, now: int, common_rooms_done: PackedInt64Array = PackedInt64Array(), walk_in_name: String = "") -> bool:
	refill(adventurers, now, common_rooms_done, walk_in_name)
	if candidates[slot].is_empty() or not refusal(adventurers, gold, beds, hire_gold(candidates[slot])).is_empty():
		return false
	var hired := candidates[slot]
	gold.spend(hire_gold(hired))
	# A slot and an arrival time belong to one candidate only.
	join(adventurers, "recruit_%d_%d" % [slot, refill_at[slot]], hired)
	candidates[slot] = {}
	refill_at[slot] = checked_at + CANDIDATE_REFILL_SECONDS
	return true


## Brings `candidate` into `adventurers` as `id`, at their level with no XP, wearing what they came
## in.
static func join(adventurers: Adventurers, id: String, candidate: Dictionary) -> void:
	# A candidate saved before rank-E ones arrived levelled is hired at level 1, as they were drawn.
	adventurers.add(id, candidate["who"], candidate["stats"], candidate["growth"], candidate.get("level", 1))
	adventurers.gear.worn[id] = candidate["worn"].duplicate()


## The candidate who arrives in `slot` at `arrived_at`, named from NAMES other than `taken`; rank E
## by RANK_E_CHANCE when they arrive at or after `better_from`, the first Common room's finish time
## (-1 for none). A rank-E one arrives at the level rank E needs, their stats grown by a level-up's
## gains for each level past the first.
static func candidate_for(slot: int, arrived_at: int, taken: PackedStringArray, better_from: int = -1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([slot, arrived_at])
	var names := PackedStringArray()
	for name: String in NAMES:
		if name not in taken:
			names.append(name)
	var leanings := LEANING_WEAPONS.keys()
	var leaning: String = leanings[rng.randi_range(0, leanings.size() - 1)]
	var leans: Array = Adventurers.PAIR_TITLES[leaning]
	var late_bloomer := rng.randf() < LATE_BLOOMER_CHANCE
	var stats := {}
	var growth := {}
	for stat: String in Adventurers.STATS:
		var points: int = (LEANING_STAT if stat in leans else OTHER_STAT) + rng.randi_range(-STAT_SPREAD, STAT_SPREAD)
		stats[stat] = maxi(1, points - LATE_BLOOMER_STAT_LOSS) if late_bloomer else points
		growth[stat] = LEANING_GROWTH if stat in leans else OTHER_GROWTH
	if late_bloomer:
		growth[leans[0]] = LATE_BLOOMER_GROWTH
	var order := PackedStringArray(Adventurers.STATS.keys())
	for i: int in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := order[i]
		order[i] = order[j]
		order[j] = swap
	var name := names[rng.randi_range(0, names.size() - 1)]
	# Drawn last, so everything else about a candidate is as it would be without a Common room.
	var rank := RANK
	if better_from >= 0 and arrived_at >= better_from and rng.randf() < RANK_E_CHANCE:
		rank = "E"
	var candidate := {
		"who": {"name": name, "rank": rank},
		"stats": stats,
		"growth": growth,
		"shown": order.slice(0, STATS_SHOWN),
		"worn": {"weapon": LEANING_WEAPONS[leaning]},
	}
	if rank == "E":
		# Drawn after the rank, so a rank-F candidate is as they were before rank-E ones levelled.
		arrive_at_level(candidate, Adventurers.PROMOTIONS["E"]["level"], rng)
	candidate["who"]["face_seed"] = _face_seed(slot, arrived_at)
	return candidate


## Makes `candidate` arrive at `level`, their stats grown by a level-up's gains, drawn from `rng`,
## for each level past the first.
static func arrive_at_level(candidate: Dictionary, level: int, rng: RandomNumberGenerator) -> void:
	for level_up: int in level - 1:
		var gains := Adventurers.gains_from(rng, candidate["growth"])
		for stat: String in gains:
			candidate["stats"][stat] += gains[stat]
	candidate["level"] = level


# The seed of the face of whoever arrives in `slot` at `arrived_at`. Not drawn from the candidate's
# generator: how much that draws depends on their rank, and a face never does, nor does it change
# anything else about them.
static func _face_seed(slot: int, arrived_at: int) -> int:
	return hash([slot, arrived_at, "face"])


## `candidate`'s title, from their stats and what they wear, as Adventurers.title_of gives it.
static func title(candidate: Dictionary) -> String:
	var totals: Dictionary = candidate["stats"].duplicate()
	for item: String in candidate["worn"].values():
		for stat: String in Gear.ITEMS[item]["bonus"]:
			totals[stat] += Gear.ITEMS[item]["bonus"][stat]
	return Adventurers.title_of(totals)


## `candidate`'s stats for the player, those not shown as "?", such as "Strength 5 · Agility ? ·
## Perception 3 · …".
static func stats_line(candidate: Dictionary) -> String:
	var parts := PackedStringArray()
	for stat: String in Adventurers.STATS:
		var value: String = str(candidate["stats"][stat]) if stat in candidate["shown"] else "?"
		parts.append("%s %s" % [Adventurers.STATS[stat], value])
	return " · ".join(parts)


## Puts the candidates into `file`, which other state shares, so one save holds the whole game.
func write(file: ConfigFile) -> void:
	file.set_value("recruits", "candidates", candidates)
	file.set_value("recruits", "refill_at", refill_at)
	file.set_value("recruits", "checked_at", checked_at)


## The candidates saved at `path`, or no slots, which the first `refill` fills, when the save has
## none.
static func load_or_start(path: String) -> Recruits:
	var recruits := Recruits.new()
	var file := ConfigFile.new()
	if file.load(path) != OK or not file.has_section("recruits"):
		return recruits
	recruits.candidates.assign(file.get_value("recruits", "candidates"))
	recruits.refill_at = file.get_value("recruits", "refill_at")
	recruits.checked_at = file.get_value("recruits", "checked_at")
	for slot: int in recruits.candidates.size():
		var candidate := recruits.candidates[slot]
		if candidate.is_empty():
			continue
		# A candidate saved before faces were made gets the one they would arrive with now.
		if not candidate["who"].has("face_seed"):
			candidate["who"]["face_seed"] = _face_seed(slot, recruits.refill_at[slot])
		# One saved with the four old stats gets the nine, filled by their class, and its weapon.
		if candidate["stats"].has("might"):
			var old: Dictionary = Adventurers.OLD_CLASSES[candidate["who"]["class"]]
			candidate["who"].erase("class")
			candidate["stats"] = Adventurers.nine_stats(candidate["stats"], old["stats"])
			candidate["growth"] = Adventurers.nine_stats(candidate["growth"], old["growth"])
			var shown := PackedStringArray()
			for stat: String in candidate["shown"]:
				shown.append(Adventurers.RENAMED_STATS.get(stat, stat))
			candidate["shown"] = shown
			candidate["worn"] = {"weapon": old["weapon"]}
	return recruits


## The names nobody arriving in `slot` may have: everyone's in `adventurers` and the other
## candidates'; every candidate's for a `slot` none has, such as a walk-in's.
func names_taken(adventurers: Adventurers, slot: int) -> PackedStringArray:
	var taken := PackedStringArray()
	for who: Dictionary in adventurers.roster.values():
		taken.append(who["name"])
	for other: int in candidates.size():
		if other != slot and not candidates[other].is_empty():
			taken.append(candidates[other]["who"]["name"])
	return taken
